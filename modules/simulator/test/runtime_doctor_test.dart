import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/runtime.dart';

void main() {
  late Directory temp;
  late HostInfo host;
  late FlutterSdk sdk;
  late CheckoutPaths checkout;
  late RuntimeStore store;
  late CustomDevicesFile devices;
  late String settings;
  late RuntimeDoctor doctor;

  const revision = 'deb287481e0123456789';

  File touch(String path, [String contents = '']) => File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_doctor');
    final sdkRoot = p.join(temp.path, 'flutter');
    touch(p.join(sdkRoot, 'bin', 'flutter'));
    touch(p.join(sdkRoot, 'bin', 'cache', 'engine.stamp'), revision);
    touch(
      p.join(
        sdkRoot,
        'bin',
        'cache',
        'artifacts',
        'engine',
        'linux-x64',
        'icudtl.dat',
      ),
    );
    sdk = FlutterSdk(root: sdkRoot, revision: revision);
    checkout = CheckoutPaths(p.join(temp.path, 'repo'));
    touch(checkout.deviceHelper);
    host = HostInfo(
      operatingSystem: 'linux',
      environment: {'HOME': temp.path, 'PATH': ''},
      temporaryDirectory: temp.path,
      workingDirectory: p.join(checkout.root, 'apps', 'raccoon_simulator'),
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
    doctor = RuntimeDoctor(
      host: host,
      store: store,
      devices: devices,
      flutterSettings: settings,
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Map<CheckKind, RuntimeCheck> check({
    FlutterSdk? withSdk,
    bool noSdk = false,
  }) {
    final checks = doctor.check(
      sdk: switch (noSdk) {
        true => null,
        false => withSdk ?? sdk,
      },
      checkout: checkout,
    );
    return {for (final check in checks) check.kind: check};
  }

  test('a fresh machine misses everything but the SDK', () {
    final checks = check();
    expect(checks[CheckKind.flutter]?.status, CheckStatus.ok);
    expect(checks[CheckKind.runner]?.status, CheckStatus.missing);
    expect(checks[CheckKind.runner]?.fixLabel, 'Build');
    expect(checks[CheckKind.engine]?.status, CheckStatus.missing);
    expect(checks[CheckKind.engine]?.fixLabel, 'Install');
    expect(checks[CheckKind.customDevices]?.status, CheckStatus.missing);
    expect(checks[CheckKind.customDevices]?.fixLabel, 'Enable');
    expect(checks[CheckKind.device]?.status, CheckStatus.missing);
    expect(checks[CheckKind.device]?.fixLabel, 'Register');
  });

  test('without an SDK nothing can be fixed but the SDK itself', () {
    final checks = check(noSdk: true);
    expect(checks[CheckKind.flutter]?.status, CheckStatus.missing);
    expect(checks[CheckKind.flutter]?.fixLabel, isNull);
    expect(checks[CheckKind.engine]?.fixLabel, isNull);
  });

  test('an SDK without ICU data offers to precache', () {
    File(RuntimeStore.icuDataOfSdk(sdk.root, platform: 'linux-x64'))
        .deleteSync();
    expect(check()[CheckKind.flutter]?.fixLabel, 'Precache');
  });

  test('passes once everything is in place', () async {
    touch(checkout.runnerBinary);
    await store.ensure(revision);
    touch(settings, jsonEncode({'enable-custom-devices': true}));
    devices.upsert(CustomDeviceConfig(deviceHelper: checkout.deviceHelper));

    final checks = check();
    expect(
      checks.values.map((check) => check.status),
      everyElement(CheckStatus.ok),
    );
  });

  test('a device registered from another checkout is only a warning', () {
    final other = touch(p.join(temp.path, 'other', 'raccoon-device'));
    devices.upsert(CustomDeviceConfig(deviceHelper: other.path));

    final device = check()[CheckKind.device];
    expect(device?.status, CheckStatus.warning);
    expect(device?.passes, isTrue);
    expect(device?.fixLabel, 'Use this checkout');
    expect(doctor.registeredHelper(), other.path);
  });

  test('a device pointing at a missing helper fails', () {
    devices.upsert(CustomDeviceConfig(deviceHelper: '/gone/raccoon-device'));
    expect(check()[CheckKind.device]?.status, CheckStatus.missing);
  });

  test('the fixer installs the engine and registers the device', () async {
    final fixer = RuntimeFixer(host: host, store: store, devices: devices);
    final lines = <String>[];

    await fixer.fix(
      CheckKind.engine,
      sdk: sdk,
      checkout: checkout,
      onLine: lines.add,
    );
    await fixer.fix(
      CheckKind.device,
      sdk: sdk,
      checkout: checkout,
      onLine: lines.add,
    );

    final checks = check();
    expect(checks[CheckKind.engine]?.status, CheckStatus.ok);
    expect(checks[CheckKind.device]?.status, CheckStatus.ok);
    expect(lines, isNotEmpty);
  });

  test('the fixer puts the SDK first on the PATH', () {
    final fixer = RuntimeFixer(
      host: HostInfo(
        operatingSystem: 'linux',
        environment: const {'PATH': '/usr/bin'},
        temporaryDirectory: '/tmp',
        workingDirectory: '/',
        executable: '/x',
      ),
    );
    expect(fixer.environmentFor(sdk), {'PATH': '${sdk.bin}:/usr/bin'});
  });

  group('HostLocator', () {
    test('finds the checkout above the working directory', () {
      expect(HostLocator.checkout(host)?.root, checkout.root);
    });

    test('finds the checkout above the executable', () {
      final fromBundle = HostInfo(
        operatingSystem: 'linux',
        environment: const {},
        temporaryDirectory: '/tmp',
        workingDirectory: '/',
        executable: p.join(checkout.root, 'apps', 'x', 'build', 'bundle', 'x'),
      );
      expect(HostLocator.checkout(fromBundle)?.root, checkout.root);
    });

    test('prefers RACCOON_SIMULATOR_ROOT', () {
      final elsewhere = HostInfo(
        operatingSystem: 'linux',
        environment: {HostLocator.rootVariable: checkout.root},
        temporaryDirectory: '/tmp',
        workingDirectory: '/',
        executable: '/usr/bin/x',
      );
      expect(HostLocator.checkout(elsewhere)?.root, checkout.root);
    });

    test('reads the SDK and its engine revision from FLUTTER_ROOT', () {
      final withRoot = HostInfo(
        operatingSystem: 'linux',
        environment: {'FLUTTER_ROOT': sdk.root, 'PATH': ''},
        temporaryDirectory: '/tmp',
        workingDirectory: '/',
        executable: '/x',
      );
      final found = HostLocator.flutterSdk(withRoot);
      expect(found?.root, File(sdk.root).resolveSymbolicLinksSync());
      expect(found?.revision, revision);
      expect(found?.flutter, p.join(found?.root ?? '', 'bin', 'flutter'));
    });
  });
}
