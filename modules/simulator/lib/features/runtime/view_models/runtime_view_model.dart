import 'dart:async';

import 'package:flutter/foundation.dart';
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
  List<RuntimeCheck> _checks = const [];
  CheckKind? _fixing;
  String? _fixError;
  var _privateSockets = true;
  late RunnerSockets _sockets = _socketsFor(_privateSockets);
  var _disposed = false;

  FlutterSdk? get sdk => _sdk;

  CheckoutPaths? get checkout => _checkout;

  /// The same list until the next [refresh].
  List<RuntimeCheck> get checks => _checks;

  /// The check whose fix is running.
  CheckKind? get fixing => _fixing;

  String? get fixError => _fixError;

  /// Whether every check passes, so a run can start.
  bool get isReady =>
      _checks.isNotEmpty && _checks.every((check) => check.passes);

  bool get privateSockets => _privateSockets;

  RunnerSockets get sockets => _sockets;

  /// Variables for `flutter run`: the SDK first on the PATH, this checkout's
  /// runner, and the socket directory.
  Map<String, String> get runEnvironment => {
    ..._fixer.environmentFor(_sdk),
    if (_checkout case final checkout?) 'RACCOON_RUNNER': checkout.runnerBinary,
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
    _checks = List.unmodifiable(
      _doctor.check(sdk: _sdk, checkout: _checkout),
    );
    _notify();
  }

  Future<void> fix(CheckKind kind) async {
    if (_fixing != null) return;
    _fixing = kind;
    _fixError = null;
    _notify();
    try {
      await _fixer.fix(kind, sdk: _sdk, checkout: _checkout, onLine: _onLine);
      _onLine('${kind.label}: done');
    } on Object catch (error) {
      _fixError = '${kind.label}: $error';
      _onLine(_fixError ?? '');
    }
    _fixing = null;
    if (_disposed) return;
    refresh();
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
