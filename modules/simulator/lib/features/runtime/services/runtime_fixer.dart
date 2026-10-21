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
        devices.upsert(CustomDeviceConfig(deviceHelper: paths.deviceHelper));
        onLine('Registered ${paths.deviceHelper} in ${devices.path}');
    }
  }

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
    await _step(
      'tool/protoc.sh',
      checkout.tool('protoc.sh'),
      const [],
      sdk: sdk,
      directory: directory,
      onLine: onLine,
    );
    final engineDir = await _step(
      'tool/engine_dir.sh',
      checkout.tool('engine_dir.sh'),
      const [],
      sdk: sdk,
      directory: directory,
      onLine: onLine,
    );
    final engine = engineDir.lastWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => throw const FixFailed('engine_dir.sh printed no path'),
    );
    await _step(
      'cmake',
      'cmake',
      ['-S', '.', '-B', 'build', '-G', 'Ninja', '-DRACCOON_ENGINE_DIR=$engine'],
      sdk: sdk,
      directory: directory,
      onLine: onLine,
    );
    await _step(
      'ninja',
      'ninja',
      const ['-C', 'build'],
      sdk: sdk,
      directory: directory,
      onLine: onLine,
    );
    if (!File(checkout.runnerBinary).existsSync()) {
      throw FixFailed('ninja finished but ${checkout.runnerBinary} is missing');
    }
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
  }) async {
    onLine('\$ $label ${arguments.join(' ')}'.trimRight());
    final ({int exitCode, List<String> stdout}) result;
    try {
      result = await commands.run(
        executable,
        arguments,
        workingDirectory: directory,
        environment: environmentFor(sdk),
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
