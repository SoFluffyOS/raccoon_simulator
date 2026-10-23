import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/services/command_runner.dart';
import 'package:simulator/features/runtime/services/host_locator.dart';
import 'package:simulator/features/runtime/services/runner_downloader.dart';

/// A fix that did not work, with what to tell the user.
final class FixFailed implements Exception {
  const FixFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Applies one [FixKind]: downloads or builds the runner, installs the
/// engine, turns custom devices on, or registers the device.
final class RuntimeFixer {
  RuntimeFixer({
    required this.host,
    this.commands = const CommandRunner(),
    RuntimeStore? store,
    CustomDevicesFile? devices,
    RunnerDownloader? downloader,
    PrebuiltRunner? prebuilt,
  }) : store = store ?? RuntimeStore.forHost(host.environment),
       devices = devices ?? CustomDevicesFile.forHost(host.environment),
       downloader = downloader ?? RunnerDownloader(),
       prebuilt = prebuilt ?? HostLocator.prebuiltRunner(host);

  final HostInfo host;
  final CommandRunner commands;
  final RuntimeStore store;
  final CustomDevicesFile devices;
  final RunnerDownloader downloader;

  /// Where Download puts the runner.
  final PrebuiltRunner prebuilt;

  /// [runner] is where runs find the runner, see `RuntimeDoctor.runner`;
  /// the device fixes register its helper.
  Future<void> fix(
    FixKind kind, {
    required FlutterSdk? sdk,
    required CheckoutPaths? checkout,
    required RunnerPaths? runner,
    required void Function(String line) onLine,
  }) async {
    switch (kind) {
      case FixKind.precache:
        await _precache(_require(sdk, 'a Flutter SDK'), onLine);
      case FixKind.download:
        await _downloadRunner(
          _require(checkout, 'the runner submodule'),
          onLine,
        );
      case FixKind.build:
        await _buildRunner(
          _require(sdk, 'a Flutter SDK'),
          _require(checkout, 'the runner submodule'),
          onLine,
        );
      case FixKind.installEngine:
        await _installEngine(_require(sdk, 'a Flutter SDK'), onLine);
      case FixKind.enableCustomDevices:
        await _step(
          'flutter config --enable-custom-devices',
          _require(sdk, 'a Flutter SDK').flutter,
          const ['config', '--enable-custom-devices'],
          sdk: sdk,
          onLine: onLine,
        );
      case FixKind.register || FixKind.useThisRunner:
        final paths = _require(runner, 'a runner');
        // One device to start with, and every other Raccoon device already
        // there follows the helper; the user adds and removes the rest.
        final present = devices.ids().where((id) => id.startsWith('raccoon'));
        for (final id in {'raccoon', ...present}) {
          final device = deviceFor(id);
          if (device == null) continue;
          devices.upsert(
            CustomDeviceConfig.forDevice(
              device,
              deviceHelper: paths.deviceHelper,
            ),
          );
        }
        onLine('Registered ${paths.deviceHelper} in ${devices.path}');
    }
  }

  /// The device behind a registered id: a built-in one by its key, else one
  /// of the user's own at the size its entry carries.
  RaccoonDevice? deviceFor(String id) {
    final key = switch (id) {
      'raccoon' => '1',
      _ when id.startsWith('raccoon-') => id.substring(8),
      _ => null,
    };
    if (key == null) return null;
    return RaccoonDevice.forKey(key) ??
        RaccoonDevice.custom(
          key,
          size: devices.sizeOf(id),
          label: devices.labelOf(id),
        );
  }

  /// Adds [device] to the tool's list, next to the registered helper.
  void addDevice(RaccoonDevice device, RunnerPaths runner) => devices.upsert(
    CustomDeviceConfig.forDevice(device, deviceHelper: runner.deviceHelper),
  );

  /// Takes a device out of the tool's list; a run on it goes on.
  bool removeDevice(String id) => devices.remove(id);

  /// The tool and the device helper both resolve `flutter` from the PATH, so
  /// the chosen SDK goes first.
  Map<String, String> environmentFor(FlutterSdk? sdk) {
    if (sdk == null) return const {};
    final separator = switch (host.isWindows) {
      true => ';',
      false => ':',
    };
    final path = host.environment['PATH'] ?? '';
    return {'PATH': '${sdk.bin}$separator$path'};
  }

  Future<void> _precache(FlutterSdk sdk, void Function(String) onLine) => _step(
    'flutter precache',
    sdk.flutter,
    ['precache', '--${_desktopPlatform()}'],
    sdk: sdk,
    onLine: onLine,
  );

  /// The newest release compatible with the checkout's pinned version,
  /// unpacked into [prebuilt]. Fails without a release for this host or
  /// without the network; Build is the fallback then.
  Future<void> _downloadRunner(
    CheckoutPaths checkout,
    void Function(String) onLine,
  ) async {
    final pinned = RunnerVersion.read(checkout.runnerVersionFile);
    if (pinned == null) {
      throw FixFailed(
        'No version in ${checkout.runnerVersionFile} to match a release',
      );
    }
    onLine(
      'Looking for a runner release ${pinned.series} for '
      '${downloader.platform} at ${downloader.releases}',
    );
    final release = await _downloading(() => downloader.find(pinned));
    if (release == null) {
      throw FixFailed(
        'No runner release ${pinned.series} for ${downloader.platform} yet; '
        'Build makes one',
      );
    }
    onLine('Downloading ${release.asset}');
    await _downloading(() => downloader.install(release, prebuilt));
    onLine('Unpacked runner ${release.version} in ${prebuilt.directory}');
  }

  /// [action], with a [DownloadFailed] turned into what the panel shows.
  static Future<T> _downloading<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DownloadFailed catch (error) {
      throw FixFailed('Could not download the runner: ${error.message}');
    }
  }

  Future<void> _buildRunner(
    FlutterSdk sdk,
    CheckoutPaths checkout,
    void Function(String) onLine,
  ) async {
    final directory = checkout.runnerDirectory;
    await _script('protoc.sh', checkout, sdk: sdk, onLine: onLine);
    final engineDir = await _script(
      'engine_dir.sh',
      checkout,
      sdk: sdk,
      onLine: onLine,
    );
    final engine = engineDir.lastWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => throw const FixFailed('engine_dir.sh printed no path'),
    );
    // On Windows the compiler, and the CMake and Ninja that come with it,
    // are on the PATH only in Visual Studio's developer environment.
    final compilers = switch (host.isWindows) {
      true => await _msvcEnvironment(sdk, onLine),
      false => null,
    };
    await _step(
      'cmake',
      _programIn(compilers, 'cmake'),
      ['-S', '.', '-B', 'build', '-G', 'Ninja', '-DRACCOON_ENGINE_DIR=$engine'],
      sdk: sdk,
      directory: directory,
      environment: compilers,
      onLine: onLine,
    );
    await _step(
      'ninja',
      _programIn(compilers, 'ninja'),
      const ['-C', 'build'],
      sdk: sdk,
      directory: directory,
      environment: compilers,
      onLine: onLine,
    );
    if (!File(checkout.runnerBinary).existsSync()) {
      throw FixFailed('ninja finished but ${checkout.runnerBinary} is missing');
    }
  }

  /// [name] as found on [environment]'s PATH, or [name] itself without one.
  /// Windows looks a program up on the PATH of the process that starts it,
  /// not the one it is given, so Visual Studio's CMake and Ninja are named
  /// by their full paths.
  static String _programIn(Map<String, String>? environment, String name) {
    if (environment == null) return name;
    for (final directory in (environment['PATH'] ?? '').split(';')) {
      if (directory.isEmpty) continue;
      final program = p.windows.join(directory, '$name.exe');
      if (File(program).existsSync()) return program;
    }
    return name;
  }

  /// One of the runner's `tool/` scripts, in its directory: run by itself,
  /// or on Windows by Git Bash, as the device helper is there.
  Future<List<String>> _script(
    String name,
    CheckoutPaths checkout, {
    required FlutterSdk sdk,
    required void Function(String) onLine,
  }) {
    final script = checkout.tool(name);
    final (executable, arguments) = switch (host.isWindows) {
      true => (
        CustomDeviceConfig.gitBashFor(
          host.environment,
          (path) => File(path).existsSync(),
        ),
        [script],
      ),
      false => (script, const <String>[]),
    };
    return _step(
      'tool/$name',
      executable,
      arguments,
      sdk: sdk,
      directory: checkout.runnerDirectory,
      onLine: onLine,
    );
  }

  /// The environment of Visual Studio's x64 developer prompt, with the SDK
  /// first on the PATH: what `vcvars64.bat` of the newest install with the
  /// C++ tools sets, as `vswhere` finds it.
  Future<Map<String, String>> _msvcEnvironment(
    FlutterSdk sdk,
    void Function(String) onLine,
  ) async {
    final programs =
        host.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final vswhere = p.windows.join(
      programs,
      'Microsoft Visual Studio',
      'Installer',
      'vswhere.exe',
    );
    if (!File(vswhere).existsSync()) {
      throw const FixFailed(
        'Build needs Visual Studio with its C++ tools; none is installed',
      );
    }
    final found = await _step(
      'vswhere',
      vswhere,
      const [
        '-latest',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '-property',
        'installationPath',
      ],
      sdk: sdk,
      onLine: onLine,
    );
    final install = found.firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => throw const FixFailed(
        'Build needs Visual Studio with its C++ tools; '
        'no installation has them',
      ),
    );
    final vcvars = p.windows.join(
      install.trim(),
      'VC',
      'Auxiliary',
      'Build',
      'vcvars64.bat',
    );
    // What vcvars sets is printed by `set`, not shown: it is the whole
    // environment.
    onLine('\$ vcvars64.bat');
    final result = await commands.run('cmd', [
      '/c',
      'call',
      vcvars,
      '>nul',
      '&&',
      'set',
    ]);
    if (result.exitCode != 0) {
      throw FixFailed('vcvars64.bat failed with exit code ${result.exitCode}');
    }
    final environment = <String, String>{};
    for (final line in result.stdout) {
      final at = line.indexOf('=');
      if (at <= 0) continue;
      final name = line.substring(0, at);
      final key = switch (name.toUpperCase()) {
        'PATH' => 'PATH',
        _ => name,
      };
      environment[key] = line.substring(at + 1);
    }
    return {
      ...environment,
      'PATH': '${sdk.bin};${environment['PATH'] ?? ''}',
    };
  }

  Future<void> _installEngine(
    FlutterSdk sdk,
    void Function(String) onLine,
  ) async {
    final revision = sdk.revision;
    if (revision == null) throw const FixFailed('The SDK has no engine stamp');
    onLine(
      'Downloading ${RuntimeStore.artifactUri(revision, platform: store.platform)}',
    );
    final runtime = await store.ensure(revision);
    onLine(
      'Installed ${p.basename(runtime.engineLibrary)} in ${runtime.directory}',
    );
  }

  Future<List<String>> _step(
    String label,
    String executable,
    List<String> arguments, {
    required FlutterSdk? sdk,
    required void Function(String) onLine,
    String? directory,
    Map<String, String>? environment,
  }) async {
    onLine('\$ $label ${arguments.join(' ')}'.trimRight());
    final ({int exitCode, List<String> stdout}) result;
    try {
      result = await commands.run(
        executable,
        arguments,
        workingDirectory: directory,
        environment: environment ?? environmentFor(sdk),
        onLine: onLine,
      );
    } on ProcessException catch (error) {
      throw FixFailed('$label could not start: ${error.message}');
    }
    if (result.exitCode != 0) {
      throw FixFailed('$label failed with exit code ${result.exitCode}');
    }
    return result.stdout;
  }

  String _desktopPlatform() => switch (host.operatingSystem) {
    'macos' => 'macos',
    'windows' => 'windows',
    _ => 'linux',
  };

  static T _require<T extends Object>(T? value, String what) {
    if (value case final value?) return value;
    throw FixFailed('Needs $what first');
  }
}
