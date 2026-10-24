import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:simulator/features/run/models/models.dart';
import 'package:simulator/features/run/services/services.dart';
import 'package:simulator/features/run/view_models/run_log.dart';

/// Starts the tool for a request; [FlutterRun.start] in the app.
typedef FlutterRunStarter = Future<FlutterRun> Function(FlutterRunRequest);

/// One `flutter run -d raccoon --machine` session at a time: start, hot
/// reload, hot restart, stop, and how long each took.
final class RunViewModel extends ChangeNotifier {
  RunViewModel({
    required RunLog log,
    FlutterRunStarter? start,
    this.stopTimeout = const Duration(seconds: 10),
  }) : _log = log,
       _start = start ?? FlutterRun.start;

  final RunLog _log;
  final FlutterRunStarter _start;

  /// How long `app.stop` and the exit after it may take before the process
  /// is killed.
  final Duration stopTimeout;

  FlutterRun? _run;
  StreamSubscription<MachineMessage>? _messages;
  StreamSubscription<String>? _errors;
  final _launchClock = Stopwatch();
  var _phase = RunPhase.idle;
  String? _appName;
  String? _appId;
  String? _directory;
  String? _vmServiceUri;
  String? _progress;
  String? _error;
  Duration? _launchTime;
  RestartKind? _restarting;
  RestartResult? _lastRestart;
  var _supportsRestart = false;
  var _disposed = false;

  RunPhase get phase => _phase;

  /// The app's name from its pubspec, which the runner's socket is named
  /// after; set from the moment a run starts.
  String? get appName => _appName;

  /// The tool's id for the app, after `app.start`.
  String? get appId => _appId;

  String? get directory => _directory;

  String? get vmServiceUri => _vmServiceUri;

  /// The step in progress, such as "Launching lib/main.dart…".
  String? get progress => _progress;

  /// Why the last run or command failed.
  String? get error => _error;

  /// From starting the tool to `app.started`.
  Duration? get launchTime => _launchTime;

  /// The reload or restart in flight.
  RestartKind? get restarting => _restarting;

  RestartResult? get lastRestart => _lastRestart;

  bool get isActive => _phase != RunPhase.idle;

  bool get canRestart =>
      _phase == RunPhase.running && _restarting == null && _supportsRestart;

  /// Starts the tool in [directory]. Does nothing while a run is active.
  Future<void> run({
    required String directory,
    required String appName,
    required String flutter,
    Map<String, String> environment = const {},
  }) async {
    if (isActive) return;
    _reset();
    _phase = RunPhase.starting;
    _directory = directory;
    _appName = appName;
    _progress = 'Starting flutter run';
    _launchClock
      ..reset()
      ..start();
    notifyListeners();
    final request = FlutterRunRequest(
      flutter: flutter,
      directory: directory,
      environment: environment,
    );
    _log.add(LogSource.tool, '\$ flutter ${request.arguments.join(' ')}');
    final FlutterRun run;
    try {
      run = await _start(request);
    } on Object catch (error) {
      _fail('Could not start flutter: $error');
      _phase = RunPhase.idle;
      _appName = null;
      _progress = null;
      _notify();
      return;
    }
    if (_disposed) {
      run.kill();
      return;
    }
    _run = run;
    _messages = run.messages.listen((message) => _onMessage(run, message));
    _errors = run.errors.listen((line) => _log.add(LogSource.error, line));
    unawaited(run.exitCode.then((code) => _onExit(run, code)));
  }

  /// Hot reload or hot restart over the machine protocol.
  Future<void> restart(RestartKind kind) async {
    final run = _run;
    final appId = _appId;
    if (run == null || appId == null || !canRestart) return;
    _restarting = kind;
    _error = null;
    notifyListeners();
    final clock = Stopwatch()..start();
    final response = await run.request('app.restart', {
      'appId': appId,
      'fullRestart': kind.fullRestart,
      'pause': false,
      'reason': 'manual',
    });
    clock.stop();
    if (!identical(run, _run)) return;
    _restarting = null;
    _lastRestart = RestartResult(
      kind: kind,
      duration: clock.elapsed,
      failure: response.failure,
    );
    switch (response.failure) {
      case final failure?:
        _fail('${kind.label} failed: $failure');
      case null:
        _log.add(
          LogSource.tool,
          '${kind.label}: ${clock.elapsedMilliseconds} ms',
        );
    }
    _notify();
  }

  /// Asks the app to stop, then waits for the tool to exit; kills the tool
  /// when that takes longer than [stopTimeout], or at once when the app has
  /// not started yet.
  Future<void> stop() async {
    final run = _run;
    if (run == null || _phase == RunPhase.stopping) return;
    _phase = RunPhase.stopping;
    _progress = 'Stopping';
    notifyListeners();
    final appId = _appId;
    if (appId == null) {
      run.kill();
      return;
    }
    await run
        .request('app.stop', {'appId': appId})
        .timeout(
          stopTimeout,
          onTimeout: () => const MachineResponse(id: 0, error: 'timeout'),
        );
    await run.exitCode.timeout(
      stopTimeout,
      onTimeout: () {
        run.kill();
        return -1;
      },
    );
  }

  void _onMessage(FlutterRun run, MachineMessage message) {
    if (_logged(message)) return;
    // A run that ended only finishes its output: logged, nothing more.
    if (!identical(run, _run)) return;
    switch (message) {
      case AppStart(:final appId, :final supportsRestart):
        _appId = appId;
        _supportsRestart = supportsRestart;
        _notify();
      case AppDebugPort(:final wsUri):
        _vmServiceUri = wsUri;
        _log.add(LogSource.tool, 'VM service at $wsUri');
        _notify();
      case AppStarted():
        _launchClock.stop();
        _launchTime = _launchClock.elapsed;
        // Stopped while it built: it stays stopping, so its exit is expected.
        if (_phase != RunPhase.stopping) _phase = RunPhase.running;
        _progress = null;
        _log.add(
          LogSource.tool,
          'Started in ${_launchClock.elapsedMilliseconds} ms',
        );
        _notify();
      case AppProgress(:final message?, finished: false):
        _progress = message;
        _log.add(LogSource.tool, message);
        _notify();
      case AppProgress(finished: true):
        if (_phase == RunPhase.starting) return;
        _progress = null;
        _notify();
      case AppProgress():
        break;
      case AppStop(:final error):
        if (error case final error?) _fail('App stopped: $error');
        _log.add(LogSource.tool, 'App stopped');
      case DaemonConnected():
      case DaemonLog():
      case AppLog():
      case PlainOutput():
      case MachineResponse():
      case OtherEvent():
        break;
    }
  }

  /// Logs [message] when it is only output; true then.
  bool _logged(MachineMessage message) {
    switch (message) {
      case DaemonLog(:final message, :final isError):
        _log.add(_source(isError), message);
      case AppLog(:final log, :final isError):
        _log.add(switch (isError) {
          true => LogSource.error,
          false => LogSource.app,
        }, log);
      case PlainOutput(:final text):
        _log.add(LogSource.app, text);
      default:
        return false;
    }
    return true;
  }

  void _onExit(FlutterRun run, int code) {
    if (!identical(run, _run)) return;
    final expected = _phase == RunPhase.stopping;
    _log.add(switch ((expected, code)) {
      (true, _) || (_, 0) => LogSource.tool,
      _ => LogSource.error,
    }, 'flutter run exited with code $code');
    if (!expected && code != 0 && _error == null) {
      _error = 'flutter run exited with code $code';
    }
    // Its output ends on its own; what still comes is logged.
    _run = null;
    _phase = RunPhase.idle;
    // The run is over: what the window shows and what quitting shuts down
    // no longer follow it.
    _appName = null;
    _appId = null;
    _progress = null;
    _restarting = null;
    _supportsRestart = false;
    _launchClock.stop();
    _notify();
  }

  void _reset() {
    _appId = null;
    _vmServiceUri = null;
    _progress = null;
    _error = null;
    _launchTime = null;
    _restarting = null;
    _lastRestart = null;
    _supportsRestart = false;
  }

  void _fail(String message) {
    _error = message;
    _log.add(LogSource.error, message);
  }

  LogSource _source(bool isError) => switch (isError) {
    true => LogSource.error,
    false => LogSource.tool,
  };

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Kills a run still in progress.
  @override
  void dispose() {
    _disposed = true;
    _run?.kill();
    unawaited(_messages?.cancel());
    unawaited(_errors?.cancel());
    super.dispose();
  }
}
