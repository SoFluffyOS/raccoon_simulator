import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/run/models/models.dart';
import 'package:simulator/features/run/services/services.dart';
import 'package:simulator/features/run/view_models/run_log.dart';
import 'package:simulator/features/run/view_models/run_view_model.dart';

/// One `flutter run` an agent started through the control endpoint: any
/// project, on any Raccoon device, beside the toolbar's own run.
final class AgentRun {
  AgentRun._({
    required this.name,
    required this.directory,
    required this.deviceId,
    required FlutterRun process,
  }) : _process = process;

  /// The runner's app name: `hello@phone`.
  final String name;

  final String directory;

  /// The Flutter tool's device: `raccoon-phone`.
  final String deviceId;

  final FlutterRun _process;
  final _started = Completer<void>();
  var _phase = RunPhase.starting;
  String? _appId;
  String? _vmServiceUri;
  String? _progress;
  var _supportsRestart = false;
  final _lines = <DeviceLogLine>[];

  RunPhase get phase => _phase;

  /// The step in progress, such as "Launching lib/main.dart…".
  String? get progress => _progress;

  String? get vmServiceUri => _vmServiceUri;

  bool get canRestart => _phase == RunPhase.running && _supportsRestart;

  /// Completes at `app.started`; fails when the tool exits first.
  Future<void> get started => _started.future;

  /// The run's lines: the tool's, the app's and the runner's.
  List<DeviceLogLine> get lines => List.unmodifiable(_lines);

  /// How many lines a run keeps.
  static const capacity = 5000;

  void _add(DeviceLogLine line) {
    _lines.add(line);
    final overflow = _lines.length - capacity;
    if (overflow > 0) _lines.removeRange(0, overflow);
  }

  /// The last [count] lines, for why a run failed.
  String tail([int count = 15]) => _lines
      .skip(math.max(0, _lines.length - count))
      .map((line) => line.text)
      .join('\n');
}

/// The runs agents started, by app name. Each one's output goes to the log
/// panel too, under its name, so the person sees it.
final class AgentRuns extends ChangeNotifier {
  AgentRuns({
    required RunLog log,
    FlutterRunStarter? start,
    this.stopTimeout = const Duration(seconds: 10),
  }) : _log = log,
       _start = start ?? FlutterRun.start;

  final RunLog _log;
  final FlutterRunStarter _start;

  /// How long `app.stop` and the exit after it may take before the tool is
  /// killed.
  final Duration stopTimeout;

  final _runs = <String, AgentRun>{};
  var _disposed = false;

  List<AgentRun> get runs => List.unmodifiable(_runs.values);

  /// The run under [name], while its tool runs.
  AgentRun? run(String name) => _runs[name];

  /// Runs [directory] on [deviceId] as [name]; returns once the tool is up.
  /// Its [AgentRun.started] says when the app is.
  Future<AgentRun> start({
    required String name,
    required String directory,
    required String deviceId,
    required String flutter,
    String? target,
    Map<String, String> environment = const {},
  }) async {
    if (_runs[name] case final running?) return running;
    final request = FlutterRunRequest(
      flutter: flutter,
      directory: directory,
      deviceId: deviceId,
      target: target,
      environment: environment,
    );
    _log.add(
      LogSource.tool,
      '[$name] \$ flutter ${request.arguments.join(' ')}',
    );
    final process = await _start(request);
    final run = AgentRun._(
      name: name,
      directory: directory,
      deviceId: deviceId,
      process: process,
    );
    run._started.future.ignore();
    _runs[name] = run;
    process.messages.listen((message) => _onMessage(run, message));
    process.errors.listen((line) => _line(run, LogSource.error, line));
    unawaited(process.exitCode.then((code) => _onExit(run, code)));
    _notify();
    return run;
  }

  /// Hot reload or restart; throws with the tool's reason when it fails.
  Future<void> restart(String name, {required bool full}) async {
    final run = _runs[name];
    if (run == null) throw StateError('$name is not running here');
    final appId = run._appId;
    if (appId == null || !run.canRestart) {
      throw StateError('$name has not started yet');
    }
    final clock = Stopwatch()..start();
    final response = await run._process.request('app.restart', {
      'appId': appId,
      'fullRestart': full,
      'pause': false,
      'reason': 'manual',
    });
    final kind = switch (full) {
      true => RestartKind.hotRestart,
      false => RestartKind.hotReload,
    };
    if (response.failure case final failure?) {
      _line(run, LogSource.error, '${kind.label} failed: $failure');
      throw StateError('${kind.label} failed: $failure');
    }
    _line(
      run,
      LogSource.tool,
      '${kind.label}: ${clock.elapsedMilliseconds} ms',
    );
  }

  /// Asks the app to stop and waits for the tool to exit, killing it past
  /// [stopTimeout].
  Future<void> stop(String name) async {
    final run = _runs[name];
    if (run == null || run._phase == RunPhase.stopping) return;
    run._phase = RunPhase.stopping;
    _notify();
    await _askToStop(run);
    await run._process.exitCode.timeout(
      stopTimeout,
      onTimeout: () {
        run._process.kill();
        return -1;
      },
    );
  }

  /// Asks the app to stop, or ends a tool that has no app yet.
  Future<void> _askToStop(AgentRun run) async {
    final appId = run._appId;
    if (appId == null) {
      run._process.kill();
      return;
    }
    await run._process
        .request('app.stop', {'appId': appId})
        .timeout(
          stopTimeout,
          onTimeout: () => const MachineResponse(id: 0, error: 'timeout'),
        );
  }

  /// Stops every run.
  Future<void> stopAll() =>
      Future.wait([for (final name in _runs.keys.toList()) stop(name)]);

  void _onMessage(AgentRun run, MachineMessage message) {
    switch (message) {
      case AppStart(:final appId, :final supportsRestart):
        run._appId = appId;
        run._supportsRestart = supportsRestart;
      case AppDebugPort(:final wsUri):
        run._vmServiceUri = wsUri;
      case AppStarted():
        if (run._phase == RunPhase.starting) run._phase = RunPhase.running;
        run._progress = null;
        if (!run._started.isCompleted) run._started.complete();
        _line(run, LogSource.tool, 'Started');
        _notify();
      case AppProgress(:final message?, finished: false):
        run._progress = message;
        _line(run, LogSource.tool, message);
        _notify();
      case AppProgress():
        break;
      case AppLog(:final log, :final isError):
        for (final line in log.split('\n')) {
          _line(run, _source(isError, LogSource.app), line);
        }
      case DaemonLog(:final message, :final isError):
        _line(run, _source(isError, LogSource.tool), message);
      case PlainOutput(:final text):
        _line(run, LogSource.app, text);
      case AppStop(:final error):
        _line(run, LogSource.tool, switch (error) {
          final error? => 'App stopped: $error',
          null => 'App stopped',
        });
      case DaemonConnected():
      case MachineResponse():
      case OtherEvent():
        break;
    }
  }

  static LogSource _source(bool isError, LogSource otherwise) =>
      switch (isError) {
        true => LogSource.error,
        false => otherwise,
      };

  /// Keeps [text] with the run, as the app's, the runner's or the tool's,
  /// and puts it in the log panel under the run's name.
  void _line(AgentRun run, LogSource source, String text) {
    if (text.isEmpty) return;
    run._add(switch (source) {
      LogSource.app || LogSource.error => DeviceLogLine.output(text),
      _ => DeviceLogLine(DeviceLogSource.tool, text),
    });
    _log.add(source, '[${run.name}] $text');
  }

  void _onExit(AgentRun run, int code) {
    _line(run, LogSource.tool, 'flutter run exited with code $code');
    if (!run._started.isCompleted) {
      run._started.completeError(
        StateError(
          'flutter run exited with code $code before ${run.name} started:\n'
          '${run.tail()}',
        ),
      );
    }
    run._phase = RunPhase.idle;
    if (identical(_runs[run.name], run)) _runs.remove(run.name);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Kills the runs still going.
  @override
  void dispose() {
    _disposed = true;
    for (final run in _runs.values) {
      run._process.kill();
    }
    super.dispose();
  }
}
