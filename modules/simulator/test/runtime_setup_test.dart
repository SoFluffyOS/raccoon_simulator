import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/runtime.dart';
import 'package:simulator/services/services.dart';

import 'support/fake_release_server.dart';

/// Plays the setup commands: `flutter precache` writes the ICU data,
/// `engine_dir.sh` prints a folder, `ninja` makes the runner binary, and
/// `flutter config` turns custom devices on. [failing] exits with 1.
final class FakeCommands implements CommandRunner {
  FakeCommands({required this.effects, this.failing});

  final Map<String, List<String> Function(List<String> arguments)> effects;
  final String? failing;
  final ran = <String>[];

  /// The environment each command in [ran] was given.
  final environments = <Map<String, String>>[];

  @override
  Future<({int exitCode, List<String> stdout})> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    void Function(String line)? onLine,
  }) async {
    final name = p.basename(executable);
    ran.add([name, ...arguments].join(' '));
    environments.add(environment);
    if (name == failing) return (exitCode: 1, stdout: const <String>[]);
    final stdout = effects[name]?.call(arguments) ?? const <String>[];
    return (exitCode: 0, stdout: stdout);
  }
}

void main() {
  late Directory temp;
  late HostInfo host;
  late FlutterSdk sdk;
  late CheckoutPaths checkout;
  late PrebuiltRunner prebuilt;
  late FakeReleaseServer releases;
  late RuntimeStore store;
  late CustomDevicesFile devices;
  late String settings;
  late String icu;
  final lines = <String>[];

  const revision = 'deb287481e0123456789';

  File touch(String path, [String contents = '']) => File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);

  setUp(() async {
    lines.clear();
    temp = Directory.systemTemp.createTempSync('simulator_setup');
    final sdkRoot = p.join(temp.path, 'flutter');
    touch(p.join(sdkRoot, 'bin', 'flutter'));
    touch(p.join(sdkRoot, 'bin', 'cache', 'engine.stamp'), revision);
    icu = p.join(
      sdkRoot,
      'bin',
      'cache',
      'artifacts',
      'engine',
      'linux-x64',
      'icudtl.dat',
    );
    sdk = FlutterSdk(root: sdkRoot, revision: revision);
    checkout = CheckoutPaths(p.join(temp.path, 'repo'));
    touch(checkout.deviceHelper);
    touch(checkout.runnerVersionFile, '0.3.0-pre.1\n');
    prebuilt = PrebuiltRunner(p.join(temp.path, 'runtime', 'runner'));
    releases = await FakeReleaseServer.start();
    host = HostInfo(
      operatingSystem: 'linux',
      environment: {'HOME': temp.path, 'PATH': ''},
      temporaryDirectory: temp.path,
      workingDirectory: checkout.root,
      executable: '/usr/bin/raccoon_simulator',
    );
    store = RuntimeStore(
      cacheDirectory: p.join(temp.path, 'engines'),
      platform: 'linux-x64',
      download: (uri) async => ZipEncoder().encode(
        Archive()..add(ArchiveFile.bytes('libflutter_engine.so', [1, 2, 3])),
      ),
    );
    devices = CustomDevicesFile(p.join(temp.path, 'custom_devices.json'));
    settings = p.join(temp.path, 'settings');
  });

  tearDown(() async {
    await releases.close();
    temp.deleteSync(recursive: true);
  });

  FakeCommands commands({String? failing}) => FakeCommands(
    failing: failing,
    effects: {
      'flutter': (arguments) {
        switch (arguments) {
          case ['precache', ...]:
            touch(icu);
          case ['config', '--enable-custom-devices']:
            touch(settings, jsonEncode({'enable-custom-devices': true}));
        }
        return const [];
      },
      'engine_dir.sh': (_) => [p.join(temp.path, 'engines', revision)],
      'ninja': (_) {
        touch(checkout.runnerBinary);
        return const [];
      },
    },
  );

  RuntimeViewModel viewModel(FakeCommands commands, {bool withSdk = true}) {
    final viewModel = RuntimeViewModel(
      host: host,
      settings: MemorySettingsStore(),
      doctor: RuntimeDoctor(
        host: host,
        store: store,
        devices: devices,
        flutterSettings: settings,
        prebuilt: prebuilt,
      ),
      fixer: RuntimeFixer(
        host: host,
        commands: commands,
        store: store,
        devices: devices,
        downloader: RunnerDownloader(
          releases: releases.releasesUri,
          platform: 'linux-x64',
        ),
        prebuilt: prebuilt,
      ),
      onLine: lines.add,
      locateSdk: (_) => switch (withSdk) {
        true => sdk,
        false => null,
      },
      locateCheckout: (_) => checkout,
    );
    addTearDown(viewModel.dispose);
    return viewModel..refresh();
  }

  const buildCommands = [
    'protoc.sh',
    'engine_dir.sh',
    'cmake -S . -B build -G Ninja -DRACCOON_ENGINE_DIR=<engine>',
    'ninja -C build',
  ];
  List<String> build() => [
    for (final command in buildCommands)
      command.replaceFirst('<engine>', p.join(temp.path, 'engines', revision)),
  ];

  test('sets up a fresh machine with the downloaded runner', () async {
    releases.addRelease(
      'runner-v0.3.1',
      platforms: ['linux-x64', 'macos-arm64'],
      archive: fakeRunnerArchive(version: '0.3.1'),
    );
    final fake = commands();
    final runtime = viewModel(fake);
    expect(runtime.isReady, isFalse);

    final settingUp = runtime.setUp();
    expect(runtime.settingUp, isTrue);
    await settingUp;

    expect(runtime.settingUp, isFalse);
    expect(runtime.fixError, isNull);
    expect(runtime.isReady, isTrue);
    expect(fake.ran, [
      'flutter precache --linux',
      'flutter config --enable-custom-devices',
    ]);
    expect(runtime.runner, prebuilt.paths);
    expect(runtime.runEnvironment['RACCOON_RUNNER'], prebuilt.binary);
    expect(RunnerVersion.read(prebuilt.versionFile)?.text, '0.3.1');
    expect(devices.ids(), ['raccoon']);
    expect(
      RuntimeDoctor(host: host, devices: devices).registeredHelper(),
      prebuilt.deviceHelper,
    );
    expect(store.installed(revision), isNotNull);
    expect(lines, contains('Download: done'));
  });

  test('devices go in and out of the picker, and setup keeps them', () async {
    releases.addRelease('runner-v0.3.1', platforms: ['linux-x64']);
    final runtime = viewModel(commands());
    await runtime.setUp();
    expect(runtime.deviceIds, ['raccoon']);
    expect(runtime.hasDevice(RaccoonDevice.tablet), isFalse);

    expect(await runtime.setDevice(RaccoonDevice.tablet, on: true), isTrue);
    expect(runtime.deviceIds, ['raccoon', 'raccoon-tablet']);
    expect(devices.sizeOf('raccoon-tablet'), '820x1180@2');
    final ipad = RaccoonDevice.custom('ipad', size: '1024x1366@2');
    expect(await runtime.setDevice(ipad, on: true), isTrue);
    expect(runtime.customDevices.map((d) => d.id), ['raccoon-ipad']);
    expect(runtime.customDevices.single.sizeArgument, '1024x1366@2');

    // Setting up again re-points what is there and adds nothing.
    await runtime.setUp();
    expect(runtime.deviceIds, ['raccoon', 'raccoon-tablet', 'raccoon-ipad']);
    expect(devices.sizeOf('raccoon-ipad'), '1024x1366@2');

    expect(await runtime.setDevice(RaccoonDevice.tablet, on: false), isTrue);
    expect(await runtime.setDevice(RaccoonDevice.tablet, on: false), isFalse);
    expect(runtime.deviceIds, ['raccoon', 'raccoon-ipad']);
  });

  test('keep only Raccoon takes the extras out of the picker', () async {
    releases.addRelease('runner-v0.3.1', platforms: ['linux-x64']);
    final runtime = viewModel(commands());
    await runtime.setUp();
    await runtime.setDevice(RaccoonDevice.tablet, on: true);
    await runtime.setDevice(RaccoonDevice.second, on: true);
    expect(runtime.deviceIds, ['raccoon', 'raccoon-tablet', 'raccoon-2']);

    runtime.keepOnlyRaccoon();
    expect(runtime.deviceIds, ['raccoon']);
    expect(devices.ids(), ['raccoon']);
  });

  test('builds the runner when no release fits', () async {
    releases.addRelease('runner-v0.2.0', platforms: ['linux-x64']);
    final fake = commands();
    final runtime = viewModel(fake);

    await runtime.setUp();

    expect(runtime.fixError, isNull);
    expect(runtime.isReady, isTrue);
    expect(fake.ran, [
      'flutter precache --linux',
      ...build(),
      'flutter config --enable-custom-devices',
    ]);
    expect(runtime.runner, checkout.runner);
    expect(File(prebuilt.binary).existsSync(), isFalse);
    expect(lines, contains(contains('No runner release 0.3.x for linux-x64')));
    expect(lines, contains('Build: done'));
  });

  test('builds the runner when the releases cannot be fetched', () async {
    final fake = commands();
    final runtime = viewModel(fake);
    await releases.close();

    await runtime.setUp();

    expect(runtime.fixError, isNull);
    expect(runtime.isReady, isTrue);
    expect(fake.ran, contains('ninja -C build'));
    expect(lines, contains(contains('Could not download the runner')));
  });

  test(
    'builds on Windows through Git Bash and Visual Studio\'s environment',
    () async {
      final git = p.join(temp.path, 'Git');
      touch(p.join(git, 'cmd', 'git.exe'));
      touch(p.join(git, 'bin', 'bash.exe'));
      final programs = p.join(temp.path, 'x86');
      touch(
        p.join(programs, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe'),
      );
      // Visual Studio's CMake and Ninja, on its environment's PATH only.
      final vsBin = p.join(temp.path, 'VS', 'bin');
      touch(p.join(vsBin, 'cmake.exe'));
      touch(p.join(vsBin, 'ninja.exe'));
      final windows = CheckoutPaths(checkout.root, isWindows: true);
      const engine = 'C:/engines/rev/windows-x64';
      final fake = FakeCommands(
        effects: {
          'bash.exe': (arguments) => switch (p.basename(arguments.single)) {
            'engine_dir.sh' => const [engine],
            _ => const [],
          },
          'vswhere.exe': (_) => const [r'C:\VS'],
          'cmd': (_) => ['Path=$vsBin;C:\\Windows', r'INCLUDE=C:\VS\inc'],
          'ninja.exe': (_) {
            touch(windows.runnerBinary);
            return const [];
          },
        },
      );
      final fixer = RuntimeFixer(
        host: HostInfo(
          operatingSystem: 'windows',
          environment: {
            'PATH': p.join(git, 'cmd'),
            'ProgramFiles(x86)': programs,
          },
          temporaryDirectory: temp.path,
          workingDirectory: checkout.root,
          executable: r'C:\raccoon_simulator.exe',
        ),
        commands: fake,
        store: store,
        devices: devices,
        prebuilt: prebuilt,
      );

      await fixer.fix(
        FixKind.build,
        sdk: sdk,
        checkout: windows,
        runner: null,
        onLine: lines.add,
      );

      expect(fake.ran, [
        'bash.exe ${windows.tool('protoc.sh')}',
        'bash.exe ${windows.tool('engine_dir.sh')}',
        'vswhere.exe -latest -products * -requires '
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64 '
            '-property installationPath',
        r'cmd /c call C:\VS\VC\Auxiliary\Build\vcvars64.bat >nul && set',
        // By their full paths: Windows would look them up on this
        // process's PATH, not the one they are given.
        'cmake.exe -S . -B build -G Ninja -DRACCOON_ENGINE_DIR=$engine',
        'ninja.exe -C build',
      ]);
      expect(fake.environments[4], {
        'PATH': '${sdk.bin};$vsBin;C:\\Windows',
        'INCLUDE': r'C:\VS\inc',
      });
    },
    skip: !Platform.isWindows,
  );

  test('stops at the first fix that fails', () async {
    final fake = commands(failing: 'cmake');
    final runtime = viewModel(fake);

    await runtime.setUp();

    expect(runtime.isReady, isFalse);
    expect(runtime.fixError, contains('cmake failed'));
    expect(fake.ran.last, startsWith('cmake'));
    expect(store.installed(revision), isNull);
    expect(File(devices.path).existsSync(), isFalse);
  });

  test('stops at a gap it cannot fix, without running anything', () async {
    final fake = commands();
    final runtime = viewModel(fake, withSdk: false);

    await runtime.setUp();

    expect(fake.ran, isEmpty);
    expect(runtime.isReady, isFalse);
    expect(File(devices.path).existsSync(), isFalse);
  });

  test('leaves a device another checkout registered alone', () async {
    touch(icu);
    touch(checkout.runnerBinary);
    await store.ensure(revision);
    touch(settings, jsonEncode({'enable-custom-devices': true}));
    final other = touch(p.join(temp.path, 'other', 'raccoon-device'));
    devices.upsert(CustomDeviceConfig(deviceHelper: other.path));
    final before = File(devices.path).readAsStringSync();
    final fake = commands();
    final runtime = viewModel(fake);

    await runtime.setUp();

    expect(fake.ran, isEmpty);
    expect(runtime.isReady, isTrue);
    expect(File(devices.path).readAsStringSync(), before);
  });

  test('one Download replaces a downloaded runner of another series', () async {
    touch(prebuilt.binary);
    touch(prebuilt.versionFile, '0.2.0\n');
    releases.addRelease(
      'runner-v0.3.0',
      platforms: ['linux-x64'],
      archive: fakeRunnerArchive(version: '0.3.0'),
    );
    final runtime = viewModel(commands());
    expect(runtime.checks[1].detail, startsWith('Downloaded 0.2.0 is not'));

    expect(await runtime.fix(FixKind.download), isTrue);

    expect(RunnerVersion.read(prebuilt.versionFile)?.text, '0.3.0');
    expect(runtime.runner, prebuilt.paths);
    expect(runtime.checks[1].status, CheckStatus.ok);
  });

  test(
    'one Download replaces a downloaded runner older than the pin',
    () async {
      touch(checkout.runnerVersionFile, '0.3.0-pre.2\n');
      touch(prebuilt.binary);
      touch(prebuilt.versionFile, '0.3.0-pre.1\n');
      releases
        ..addRelease(
          'runner-v0.3.0-pre.2',
          platforms: ['linux-x64'],
          archive: fakeRunnerArchive(version: '0.3.0-pre.2'),
        )
        ..addRelease('runner-v0.3.0-pre.1', platforms: ['linux-x64']);
      final runtime = viewModel(commands());
      expect(runtime.runner, isNot(prebuilt.paths));
      expect(
        runtime.checks[1].detail,
        startsWith('Downloaded 0.3.0-pre.1 is older than 0.3.0-pre.2'),
      );

      expect(await runtime.fix(FixKind.download), isTrue);

      expect(RunnerVersion.read(prebuilt.versionFile)?.text, '0.3.0-pre.2');
      expect(runtime.runner, prebuilt.paths);
      expect(runtime.checks[1].status, CheckStatus.ok);
    },
  );
}
