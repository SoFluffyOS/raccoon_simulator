import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/runtime.dart';
import 'package:simulator/services/services.dart';

/// Plays the setup commands: `flutter precache` writes the ICU data,
/// `engine_dir.sh` prints a folder, `ninja` makes the runner binary, and
/// `flutter config` turns custom devices on. [failing] exits with 1.
final class FakeCommands implements CommandRunner {
  FakeCommands({required this.effects, this.failing});

  final Map<String, List<String> Function(List<String> arguments)> effects;
  final String? failing;
  final ran = <String>[];

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
  late RuntimeStore store;
  late CustomDevicesFile devices;
  late String settings;
  late String icu;
  final lines = <String>[];

  const revision = 'deb287481e0123456789';

  File touch(String path, [String contents = '']) => File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);

  setUp(() {
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

  tearDown(() => temp.deleteSync(recursive: true));

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
      ),
      fixer: RuntimeFixer(
        host: host,
        commands: commands,
        store: store,
        devices: devices,
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

  test('sets up a fresh machine until Raccoon is a device', () async {
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
      'protoc.sh',
      'engine_dir.sh',
      'cmake -S . -B build -G Ninja '
          '-DRACCOON_ENGINE_DIR=${p.join(temp.path, 'engines', revision)}',
      'ninja -C build',
      'flutter config --enable-custom-devices',
    ]);
    expect(devices.ids(), ['raccoon']);
    expect(store.installed(revision), isNotNull);
  });

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
}
