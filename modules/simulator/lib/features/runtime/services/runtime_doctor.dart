import 'dart:convert';
import 'dart:io';

import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/services/host_locator.dart';

/// Checks what `flutter run -d raccoon` needs, the way `raccoon_device
/// doctor` does, and says which fixes apply to each gap.
final class RuntimeDoctor {
  RuntimeDoctor({
    required this.host,
    RuntimeStore? store,
    CustomDevicesFile? devices,
    String? flutterSettings,
    PrebuiltRunner? prebuilt,
  }) : store = store ?? RuntimeStore.forHost(host.environment),
       devices = devices ?? CustomDevicesFile.forHost(host.environment),
       flutterSettings = flutterSettings ?? HostLocator.flutterSettings(host),
       prebuilt = prebuilt ?? HostLocator.prebuiltRunner(host);

  static const deviceId = 'raccoon';

  final HostInfo host;
  final RuntimeStore store;
  final CustomDevicesFile devices;

  /// The tool's settings file.
  final String flutterSettings;

  /// Where a downloaded runner lives.
  final PrebuiltRunner prebuilt;

  /// Where runs find the runner: the checkout's build when there is one,
  /// else the downloaded runner when it is compatible with the checkout's
  /// pinned version, else the checkout, which Build or Download fills. Null
  /// without a checkout.
  RunnerPaths? runner(CheckoutPaths? checkout) {
    if (checkout == null) return null;
    if (File(checkout.runnerBinary).existsSync()) return checkout.runner;
    if (compatibleDownload(checkout) != null) return prebuilt.paths;
    return checkout.runner;
  }

  /// The downloaded runner's version when it is installed, compatible
  /// with [checkout]'s pinned version and no older than it, else null: an
  /// older one lacks what the pin brought.
  RunnerVersion? compatibleDownload(CheckoutPaths checkout) {
    final installed = downloaded();
    final pinned = RunnerVersion.read(checkout.runnerVersionFile);
    if (installed == null || pinned == null) return null;
    if (!installed.isCompatibleWith(pinned)) return null;
    if (installed.isOlderThan(pinned)) return null;
    return installed;
  }

  /// The downloaded runner's version, or null when none is installed: one
  /// half unpacked (no device helper beside its binary) is none, so setup
  /// downloads it again.
  RunnerVersion? downloaded() => prebuilt.version;

  List<RuntimeCheck> check({
    required FlutterSdk? sdk,
    required CheckoutPaths? checkout,
    required RunnerPaths? runner,
  }) => [
    _flutter(sdk),
    _runner(checkout, runner),
    _engine(sdk),
    _customDevices(),
    _device(checkout, runner),
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
        fixes: const [FixKind.precache],
      );
    }
    return RuntimeCheck(
      kind: CheckKind.flutter,
      status: CheckStatus.ok,
      detail: sdk.root,
    );
  }

  RuntimeCheck _runner(CheckoutPaths? checkout, RunnerPaths? runner) {
    if (checkout == null || runner == null) {
      return const RuntimeCheck(
        kind: CheckKind.runner,
        status: CheckStatus.missing,
        detail:
            'raccoon/native/raccoon_runner not found. Run from the repository, '
            'or '
            'set ${HostLocator.rootVariable}.',
      );
    }
    if (File(runner.binary).existsSync()) {
      return RuntimeCheck(
        kind: CheckKind.runner,
        status: CheckStatus.ok,
        detail: switch (runner.binary == prebuilt.binary) {
          true => 'Downloaded ${downloaded() ?? ''}: ${runner.binary}',
          false => runner.binary,
        },
      );
    }
    final pinned = RunnerVersion.read(checkout.runnerVersionFile);
    final missingTools = [
      for (final tool in const ['cmake', 'ninja'])
        if (HostLocator.findOnPath(tool, host) == null) tool,
    ];
    final build = switch (missingTools) {
      [] => 'Build takes a few minutes the first time',
      final tools => 'Build needs ${tools.join(' and ')} on PATH',
    };
    final stale = switch (downloaded()) {
      final version? when pinned != null && version.isCompatibleWith(pinned) =>
        'Downloaded $version is older than $pinned. ',
      final version? when pinned != null =>
        'Downloaded $version is not ${pinned.series}. ',
      _ => '',
    };
    return RuntimeCheck(
      kind: CheckKind.runner,
      status: CheckStatus.missing,
      detail: switch (pinned) {
        null => 'Not built yet. $build',
        final pinned =>
          '${stale}Not built yet. Download fetches release ${pinned.series}; '
              '$build',
      },
      fixes: [if (pinned != null) FixKind.download, FixKind.build],
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
      fixes: const [FixKind.installEngine],
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
      fixes: [FixKind.enableCustomDevices],
    );
  }

  RuntimeCheck _device(CheckoutPaths? checkout, RunnerPaths? runner) {
    final helper = registeredHelper();
    final register = [if (runner != null) FixKind.register];
    if (helper == null) {
      return RuntimeCheck(
        kind: CheckKind.device,
        status: CheckStatus.missing,
        detail: 'No "$deviceId" entry in ${devices.path}',
        fixes: register,
      );
    }
    if (runner != null && helper == runner.deviceHelper) {
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
        fixes: register,
      );
    }
    // This checkout's other helper: the built runner's while the download
    // is in use, or the other way round. Editor runs go through the helper,
    // so it must be the one whose runner runs are using.
    if (runner != null &&
        (helper == checkout?.deviceHelper || helper == prebuilt.deviceHelper)) {
      return RuntimeCheck(
        kind: CheckKind.device,
        status: CheckStatus.missing,
        detail: 'Points at $helper, not at the runner in use: ${runner.binary}',
        fixes: register,
      );
    }
    return RuntimeCheck(
      kind: CheckKind.device,
      status: CheckStatus.warning,
      detail:
          'Uses another checkout\'s helper: $helper. Runs from here still '
          'use ${runner?.binary ?? 'this checkout\'s runner'}.',
      fixes: [if (runner != null) FixKind.useThisRunner],
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

  /// The helper the "raccoon" entry runs, or null without an entry: the
  /// word before `ping`, past the `bash.exe` that starts it on Windows.
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
          'ping': [..., final String helper, 'ping'],
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
