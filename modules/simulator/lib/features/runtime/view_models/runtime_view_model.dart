import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/services/services.dart';
import 'package:simulator/features/session/session.dart';
import 'package:simulator/services/services.dart';

/// The runtime panel: what is ready, the fix in progress, and where run
/// sockets go.
final class RuntimeViewModel extends ChangeNotifier {
  RuntimeViewModel({
    required this.host,
    required SettingsStore settings,
    required RuntimeDoctor doctor,
    required RuntimeFixer fixer,
    required void Function(String line) onLine,
    void Function(RunnerSockets sockets)? onSocketsChanged,
    FlutterSdk? Function(HostInfo host)? locateSdk,
    CheckoutPaths? Function(HostInfo host)? locateCheckout,
  }) : _settings = settings,
       _doctor = doctor,
       _fixer = fixer,
       _onLine = onLine,
       _onSocketsChanged = onSocketsChanged,
       _locateSdk = locateSdk ?? HostLocator.flutterSdk,
       _locateCheckout = locateCheckout ?? HostLocator.checkout;

  final HostInfo host;
  final SettingsStore _settings;
  final RuntimeDoctor _doctor;
  final RuntimeFixer _fixer;
  final void Function(String line) _onLine;
  final void Function(RunnerSockets sockets)? _onSocketsChanged;
  final FlutterSdk? Function(HostInfo host) _locateSdk;
  final CheckoutPaths? Function(HostInfo host) _locateCheckout;

  FlutterSdk? _sdk;
  CheckoutPaths? _checkout;
  RunnerPaths? _runner;
  List<RuntimeCheck> _checks = const [];
  FixKind? _fixing;
  String? _fixError;
  var _settingUp = false;
  var _privateSockets = true;
  late RunnerSockets _sockets = _socketsFor(_privateSockets);
  var _disposed = false;

  FlutterSdk? get sdk => _sdk;

  CheckoutPaths? get checkout => _checkout;

  /// Where runs find the runner, see [RuntimeDoctor.runner].
  RunnerPaths? get runner => _runner;

  /// The same list until the next [refresh].
  List<RuntimeCheck> get checks => _checks;

  /// The fix that is running.
  FixKind? get fixing => _fixing;

  String? get fixError => _fixError;

  /// Whether [setUp] is working through the fixes.
  bool get settingUp => _settingUp;

  /// Whether every check passes, so a run can start.
  bool get isReady =>
      _checks.isNotEmpty && _checks.every((check) => check.passes);

  /// Whether a check ran and something is missing: the window then points
  /// at setup.
  bool get needsSetup => _checks.isNotEmpty && !isReady;

  bool get privateSockets => _privateSockets;

  RunnerSockets get sockets => _sockets;

  /// Variables for `flutter run`: the SDK first on the PATH, the runner in
  /// use, and the socket directory.
  Map<String, String> get runEnvironment => {
    ..._fixer.environmentFor(_sdk),
    if (_runner case final runner?) 'RACCOON_RUNNER': runner.binary,
    ..._sockets.environment,
  };

  /// Loads the saved socket choice and runs the checks.
  Future<void> init() async {
    final saved = await _settings.privateSockets();
    _privateSockets = saved ?? true;
    _sockets = _socketsFor(_privateSockets);
    _onSocketsChanged?.call(_sockets);
    refresh();
  }

  void refresh() {
    _sdk = _locateSdk(host);
    _checkout = _locateCheckout(host);
    _runner = _doctor.runner(_checkout);
    _checks = List.unmodifiable(
      _doctor.check(sdk: _sdk, checkout: _checkout, runner: _runner),
    );
    _deviceIds = List.unmodifiable(
      _fixer.devices.ids().where((id) => id.startsWith('raccoon')),
    );
    _notify();
  }

  List<String> _deviceIds = const [];

  /// The Raccoon devices the Flutter tool lists, `raccoon` first.
  List<String> get deviceIds => _deviceIds;

  /// The devices of the user's own in the tool's list, neither `raccoon`
  /// nor a built-in one.
  List<RaccoonDevice> get customDevices => [
    for (final id in _deviceIds)
      if (id != 'raccoon' && RaccoonDevice.forKey(id.substring(8)) == null)
        ?_fixer.deviceFor(id),
  ];

  /// Whether [device] is in the tool's list.
  bool hasDevice(RaccoonDevice device) => _deviceIds.contains(device.id);

  /// Puts [device] in the tool's list, or takes it out. Needs a registered
  /// runner to point the device at; false without one.
  Future<bool> setDevice(RaccoonDevice device, {required bool on}) async {
    if (on) {
      final runner = _runner;
      if (runner == null) return false;
      _fixer.addDevice(device, runner);
      _onLine('Added ${device.id} (${device.label})');
    } else {
      if (!_fixer.removeDevice(device.id)) return false;
      _onLine('Removed ${device.id}');
    }
    refresh();
    return true;
  }

  /// Applies [kind] and checks again. True when the fix worked.
  Future<bool> fix(FixKind kind) async {
    if (_fixing != null) return false;
    _fixing = kind;
    _fixError = null;
    _notify();
    var worked = true;
    try {
      await _fixer.fix(
        kind,
        sdk: _sdk,
        checkout: _checkout,
        runner: _runner,
        onLine: _onLine,
      );
      _onLine('${kind.label}: done');
    } on Object catch (error) {
      worked = false;
      _fixError = '${kind.label}: $error';
      _onLine(_fixError ?? '');
    }
    _fixing = null;
    if (_disposed) return false;
    refresh();
    return worked;
  }

  /// Applies every missing check's fixes in order, so a fresh machine gets
  /// the runner (downloaded, or built when no release fits or the network
  /// is down), the engine, custom devices and the "raccoon" device, and
  /// `flutter devices` lists Raccoon. Stops at a gap with no fix or whose
  /// fixes all fail. A warning stays: a device another checkout registered
  /// still runs.
  Future<void> setUp() async {
    if (_settingUp || _fixing != null) return;
    _settingUp = true;
    _notify();
    for (final kind in CheckKind.values) {
      final check = _checkOf(kind);
      if (check == null || check.passes) continue;
      if (!await _fixAny(check.fixes)) break;
    }
    _settingUp = false;
    _notify();
  }

  /// Tries [fixes] in order until one works.
  Future<bool> _fixAny(List<FixKind> fixes) async {
    for (final kind in fixes) {
      if (await fix(kind)) return true;
    }
    return false;
  }

  RuntimeCheck? _checkOf(CheckKind kind) {
    for (final check in _checks) {
      if (check.kind == kind) return check;
    }
    return null;
  }

  Future<void> setPrivateSockets(bool value) async {
    if (value == _privateSockets) return;
    _privateSockets = value;
    _sockets = _socketsFor(value);
    _onSocketsChanged?.call(_sockets);
    _notify();
    await _settings.setPrivateSockets(value);
  }

  RunnerSockets _socketsFor(bool private) => RunnerSockets.forHost(
    operatingSystem: host.operatingSystem,
    environment: host.environment,
    temporaryDirectory: host.temporaryDirectory,
    private: private,
  );

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
