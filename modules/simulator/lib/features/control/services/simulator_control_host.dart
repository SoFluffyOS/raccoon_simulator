import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/features/board/board.dart';
import 'package:simulator/features/project/project.dart';
import 'package:simulator/features/run/run.dart';
import 'package:simulator/features/runtime/runtime.dart';
import 'package:simulator/features/session/session.dart';
import 'package:simulator/features/viewer/viewer.dart';

/// The simulator as a control endpoint's host: agents list its devices,
/// run projects on them, and drive the apps on its board through the
/// connections the simulator holds, so the person at the board sees every
/// step. Each action shows on the board, which comes up if it was not, and
/// in the log panel.
final class SimulatorControlHost implements RaccoonControlHost {
  SimulatorControlHost({
    required this.sessions,
    required this.hostRun,
    required this.agentRuns,
    required this.runtime,
    required this.board,
    required this.viewer,
    required this.log,
    required this.environment,
    required this.stopHostRun,
    this.runTimeout = const Duration(minutes: 5),
  });

  final SessionService sessions;

  /// The toolbar's run.
  final RunViewModel hostRun;

  final AgentRuns agentRuns;
  final RuntimeViewModel runtime;
  final BoardViewModel board;
  final ViewerViewModel viewer;
  final RunLog log;

  /// The host's environment, for where runners keep their logs.
  final Map<String, String> environment;

  /// Stops the toolbar's run and its runner.
  final Future<void> Function() stopHostRun;

  /// How long a run may take to its first frame.
  final Duration runTimeout;

  @override
  String get kind => 'simulator';

  @override
  List<RaccoonControlDevice> devices() {
    final custom = {
      for (final device in runtime.customDevices) device.id: device,
    };
    return [
      for (final id in runtime.deviceIds)
        RaccoonControlDevice.of(
          id,
          label: custom[id]?.label,
          size: custom[id]?.sizeArgument,
        ),
    ];
  }

  @override
  List<RaccoonControlApp> apps() => [
    for (final session in sessions.sessions)
      SimulatorControlApp._(this, session.name),
  ];

  SimulatorControlApp? _app(String name) => switch (sessions.session(name)) {
    null => null,
    _ => SimulatorControlApp._(this, name),
  };

  @override
  Future<RaccoonControlApp> run(
    String project, {
    required String device,
    String? target,
  }) async {
    _readyFlutter();
    if (!runtime.deviceIds.contains(device)) {
      throw RaccoonControlError(
        RaccoonControlError.badParams,
        '$device is not registered with the Flutter tool; registered: '
        '${runtime.deviceIds.join(', ')}. Add it with raccoon_device add.',
      );
    }
    final SimulatorProject chosen;
    try {
      chosen = ProjectReader.read(p.absolute(project));
    } on ProjectError catch (error) {
      throw RaccoonControlError(RaccoonControlError.badParams, error.message);
    }
    final name = RaccoonControlDevice.appNameOn(chosen.appName, device);
    if (_app(name) case final running?) return running;
    // Runs of one project take turns: two tools building into its build/
    // at once overwrite each other's bundle.
    final before = _building[chosen.directory] ?? Future<void>.value();
    final turn = Completer<void>();
    _building[chosen.directory] = turn.future;
    try {
      await before;
      if (_app(name) case final running?) return running;
      return await _start(name, chosen, device: device, target: target);
    } finally {
      turn.complete();
      if (identical(_building[chosen.directory], turn.future)) {
        unawaited(_building.remove(chosen.directory));
      }
    }
  }

  final _building = <String, Future<void>>{};

  Future<RaccoonControlApp> _start(
    String name,
    SimulatorProject chosen, {
    required String device,
    String? target,
  }) async {
    final flutter = _readyFlutter();
    viewer.showBoard();
    sessions.expectFresh(name, since: DateTime.now());
    final AgentRun started;
    try {
      started = await agentRuns.start(
        name: name,
        directory: chosen.directory,
        deviceId: device,
        flutter: flutter,
        target: target,
        environment: runtime.runEnvironment,
      );
    } on Object catch (error) {
      sessions.cancelFresh(name);
      throw RaccoonControlError(
        RaccoonControlError.failed,
        'flutter run did not start: $error',
      );
    }
    return _firstFrame(name, started);
  }

  /// The flutter executable, once the runtime can run.
  String _readyFlutter() {
    final why = switch (runtime) {
      RuntimeViewModel(sdk: null) => 'no Flutter SDK found',
      RuntimeViewModel(settingUp: true) =>
        'the runtime is being set up; try again once it is done',
      RuntimeViewModel(isReady: false) =>
        'the runtime needs setup: see the simulator\'s settings',
      _ => null,
    };
    if (why != null) {
      throw RaccoonControlError(RaccoonControlError.failed, why);
    }
    return switch (runtime.sdk) {
      final sdk? => sdk.flutter,
      null => throw const RaccoonControlError(
        RaccoonControlError.failed,
        'no Flutter SDK found',
      ),
    };
  }

  /// The app once its runner is connected and has drawn; the run's failure
  /// or a timeout otherwise.
  Future<RaccoonControlApp> _firstFrame(String name, AgentRun started) async {
    final clock = Stopwatch()..start();
    var exited = false;
    var up = false;
    unawaited(
      started.started.then<void>(
        (_) => up = true,
        onError: (Object _) => exited = true,
      ),
    );
    // Drawn, and the tool attached: its hot reload and VM service work.
    while (clock.elapsed < runTimeout) {
      if (_app(name) case final app?
          when up && app.client.latestFrame != null) {
        return app;
      }
      if (sessions.startupFailure(name) case final failure?) {
        await _abandon(name);
        throw RaccoonControlError(
          RaccoonControlError.failed,
          '$name stopped before its first frame: '
          '${failure.exception ?? 'see its logs'}',
        );
      }
      if (exited) {
        sessions.cancelFresh(name);
        throw RaccoonControlError(
          RaccoonControlError.failed,
          'flutter run ended before $name drew:\n${started.tail()}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await _abandon(name);
    throw RaccoonControlError(
      RaccoonControlError.failed,
      'no frame from $name in ${runTimeout.inSeconds} s:\n${started.tail()}',
    );
  }

  Future<void> _abandon(String name) async {
    await agentRuns.stop(name);
    sessions.cancelFresh(name);
    sessions.session(name)?.client.shutdown();
  }

  @override
  void announce(RaccoonControlApp? app, String action) {
    viewer.showBoard();
    log.add(LogSource.tool, switch (app) {
      final app? => 'Agent: $action on ${app.name}',
      null => 'Agent: $action',
    });
  }
}

/// An app on the simulator's board, as the control endpoint drives it. It
/// looks its session up by name at every step: a new run brings a new
/// runner under the same name.
final class SimulatorControlApp implements RaccoonControlApp {
  SimulatorControlApp._(this._host, this.name);

  final SimulatorControlHost _host;

  @override
  final String name;

  RunnerSession get _session => switch (_host.sessions.session(name)) {
    final session? => session,
    null => throw RaccoonControlError(
      RaccoonControlError.noApp,
      '$name is no longer running',
    ),
  };

  AgentRun? get _agentRun => _host.agentRuns.run(name);

  bool get _isHostRun => _host.hostRun.appName == name;

  @override
  RunnerClient get client => _session.client;

  @override
  DeviceSize get size {
    if (client.size case (:final width, :final height, :final pixelRatio)?) {
      return (
        width: width / pixelRatio,
        height: height / pixelRatio,
        pixelRatio: pixelRatio,
      );
    }
    final frame =
        _host.board.frames.where((frame) => frame.name == name).firstOrNull ??
        RaccoonBoardFrame.initial(name);
    return (
      width: frame.size.width,
      height: frame.size.height,
      pixelRatio: frame.pixelRatio,
    );
  }

  @override
  String get startedBy => switch ((_agentRun, _isHostRun)) {
    (_?, _) => 'agent',
    (null, true) => 'host',
    (null, false) => 'editor',
  };

  @override
  String? get vmServiceUri =>
      switch ((_agentRun, _isHostRun)) {
        (final run?, _) => run.vmServiceUri,
        (null, true) => _host.hostRun.vmServiceUri,
        (null, false) => null,
      } ??
      _session.vmServiceUri;

  @override
  bool get canReload => switch ((_agentRun, _isHostRun)) {
    (final run?, _) => run.canRestart,
    (null, true) => _host.hostRun.canRestart,
    (null, false) => false,
  };

  /// The board's view gives GPU buffers back.
  @override
  bool get releasesGpuFrames => false;

  @override
  Future<void> hotReload() => _restart(RestartKind.hotReload);

  @override
  Future<void> hotRestart() => _restart(RestartKind.hotRestart);

  Future<void> _restart(RestartKind kind) async {
    if (_agentRun != null) {
      await _host.agentRuns.restart(name, full: kind.fullRestart);
      return;
    }
    await _host.hostRun.restart(kind);
    if (_host.hostRun.lastRestart?.failure case final failure?) {
      throw StateError('${kind.label} failed: $failure');
    }
  }

  @override
  Future<void> stop() async {
    final client = this.client;
    if (_agentRun != null) {
      await _host.agentRuns.stop(name);
      // The tool does not stop its runner when it is killed.
      if (_host.sessions.session(name) != null) client.shutdown();
      return;
    }
    if (_isHostRun) {
      await _host.stopHostRun();
      return;
    }
    client.shutdown();
  }

  /// As the board's size menu does: the frame takes the size, its view
  /// resizes the app, and the app's next run starts at it.
  @override
  Future<void> resize(DeviceSize size) async {
    _host.viewer.showBoard();
    _host.board.frameFor(name);
    _host.board.setSize(
      name,
      Size(size.width, size.height),
      size.pixelRatio,
    );
  }

  @override
  List<DeviceLogLine> logLines() => switch (_agentRun) {
    final run? => run.lines,
    null => RunnerLog.forHost(_host.environment).read(name),
  };
}
