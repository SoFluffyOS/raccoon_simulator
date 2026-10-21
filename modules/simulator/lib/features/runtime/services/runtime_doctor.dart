import 'dart:convert';
import 'dart:io';

import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/services/host_locator.dart';

/// Checks what `flutter run -d raccoon` needs, the way `raccoon_device
/// doctor` does, and says which fix applies to each gap.
final class RuntimeDoctor {
  RuntimeDoctor({
    required this.host,
    RuntimeStore? store,
    CustomDevicesFile? devices,
    String? flutterSettings,
  }) : store = store ?? RuntimeStore.forHost(host.environment),
       devices = devices ?? CustomDevicesFile.forHost(host.environment),
       flutterSettings = flutterSettings ?? HostLocator.flutterSettings(host);

  static const deviceId = 'raccoon';

  final HostInfo host;
  final RuntimeStore store;
  final CustomDevicesFile devices;

  /// The tool's settings file.
  final String flutterSettings;

  List<RuntimeCheck> check({
    required FlutterSdk? sdk,
    required CheckoutPaths? checkout,
  }) => [
    _flutter(sdk),
    _runner(checkout),
    _engine(sdk),
    _customDevices(),
    _device(checkout),
  ];

  RuntimeCheck _flutter(FlutterSdk? sdk) {
    if (sdk == null) {
      return const RuntimeCheck(
        kind: CheckKind.flutter,
        status: CheckStatus.missing,
        detail: 'No flutter found. Set FLUTTER_ROOT or put flutter on PATH.',
      );
    }
    final icu = RuntimeStore.icuDataOfSdk(sdk.root, platform: store.platform);
    if (!File(icu).existsSync()) {
      return RuntimeCheck(
        kind: CheckKind.flutter,
        status: CheckStatus.missing,
        detail: '${sdk.root}: no ICU data for ${store.platform} yet',
        fixLabel: 'Precache',
      );
    }
    return RuntimeCheck(
      kind: CheckKind.flutter,
      status: CheckStatus.ok,
      detail: sdk.root,
    );
  }

  RuntimeCheck _runner(CheckoutPaths? checkout) {
    if (checkout == null) {
      return const RuntimeCheck(
        kind: CheckKind.runner,
        status: CheckStatus.missing,
        detail:
            'native/raccoon_runner not found. Run from the repository, or '
            'set ${HostLocator.rootVariable}.',
      );
    }
    if (File(checkout.runnerBinary).existsSync()) {
      return RuntimeCheck(
        kind: CheckKind.runner,
        status: CheckStatus.ok,
        detail: checkout.runnerBinary,
      );
    }
    final missingTools = [
      for (final tool in const ['cmake', 'ninja'])
        if (HostLocator.findOnPath(tool, host) == null) tool,
    ];
    return RuntimeCheck(
      kind: CheckKind.runner,
      status: CheckStatus.missing,
      detail: switch (missingTools) {
        [] => 'Not built yet (CMake and Ninja, a few minutes the first time)',
        final tools => 'Not built yet; needs ${tools.join(' and ')} on PATH',
      },
      fixLabel: 'Build',
    );
  }

  RuntimeCheck _engine(FlutterSdk? sdk) {
    final revision = sdk?.revision;
    if (revision == null) {
      return const RuntimeCheck(
        kind: CheckKind.engine,
        status: CheckStatus.missing,
        detail: 'Needs a Flutter SDK with an engine stamp',
      );
    }
    if (store.installed(revision) case final runtime?) {
      return RuntimeCheck(
        kind: CheckKind.engine,
        status: CheckStatus.ok,
        detail: runtime.directory,
      );
    }
    return RuntimeCheck(
      kind: CheckKind.engine,
      status: CheckStatus.missing,
      detail: 'Engine ${_short(revision)} for ${store.platform} not installed',
      fixLabel: 'Install',
    );
  }

  RuntimeCheck _customDevices() {
    if (customDevicesEnabled()) {
      return const RuntimeCheck(
        kind: CheckKind.customDevices,
        status: CheckStatus.ok,
        detail: 'flutter config --enable-custom-devices',
      );
    }
    return const RuntimeCheck(
      kind: CheckKind.customDevices,
      status: CheckStatus.missing,
      detail: 'The tool ignores custom devices until this is on',
      fixLabel: 'Enable',
    );
  }

  RuntimeCheck _device(CheckoutPaths? checkout) {
    final helper = registeredHelper();
    if (helper == null) {
      return RuntimeCheck(
        kind: CheckKind.device,
        status: CheckStatus.missing,
        detail: 'No "$deviceId" entry in ${devices.path}',
        fixLabel: switch (checkout) {
          null => null,
          _ => 'Register',
        },
      );
    }
    if (checkout != null && helper == checkout.deviceHelper) {
      return RuntimeCheck(
        kind: CheckKind.device,
        status: CheckStatus.ok,
        detail: helper,
      );
    }
    if (!File(helper).existsSync()) {
      return RuntimeCheck(
        kind: CheckKind.device,
        status: CheckStatus.missing,
        detail: 'Points at a missing helper: $helper',
        fixLabel: switch (checkout) {
          null => null,
          _ => 'Register',
        },
      );
    }
    return RuntimeCheck(
      kind: CheckKind.device,
      status: CheckStatus.warning,
      detail:
          'Uses another checkout\'s helper: $helper. Runs still use this '
          'checkout\'s runner.',
      fixLabel: switch (checkout) {
        null => null,
        _ => 'Use this checkout',
      },
    );
  }

  /// Whether the tool's settings turn custom devices on.
  bool customDevicesEnabled() {
    final file = File(flutterSettings);
    if (!file.existsSync()) return false;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map && decoded['enable-custom-devices'] == true;
    } on FormatException {
      return false;
    }
  }

  /// The helper the "raccoon" entry runs, or null without an entry.
  String? registeredHelper() {
    final file = File(devices.path);
    if (!file.existsSync()) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return null;
    }
    if (decoded case {'custom-devices': final List<Object?> entries}) {
      for (final entry in entries) {
        if (entry case {
          'id': deviceId,
          'ping': [final String helper, ...],
        }) {
          return helper;
        }
      }
    }
    return null;
  }

  static String _short(String revision) => switch (revision.length > 10) {
    true => revision.substring(0, 10),
    false => revision,
  };
}
