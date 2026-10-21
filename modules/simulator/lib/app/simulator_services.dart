import 'dart:async';

import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/app/simulator_options.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';

/// Every view model and service of one simulator window, wired together.
final class SimulatorServices {
  SimulatorServices._({
    required this.log,
    required this.run,
    required this.sessions,
    required this.runtime,
    required this.project,
    required this.viewer,
    required this.controller,
  });

  factory SimulatorServices.create({
    required HostInfo host,
    required SettingsStore settings,
    FlutterRunStarter? startFlutter,
    DirectoryPicker? pickDirectory,
  }) {
    final log = RunLog();
    final sessions = SessionService(
      connect: RunnerClient.connect,
      onConnected: const IdePlatformChannels().register,
    );
    final runtime = RuntimeViewModel(
      host: host,
      settings: settings,
      doctor: RuntimeDoctor(host: host),
      fixer: RuntimeFixer(host: host),
      onLine: (line) => log.add(LogSource.setup, line),
      onSocketsChanged: (sockets) => sessions.follow(sockets.discovery),
    );
    final run = RunViewModel(log: log, start: startFlutter);
    final project = ProjectViewModel(
      settings: settings,
      pickDirectory: pickDirectory,
    );
    return SimulatorServices._(
      log: log,
      run: run,
      sessions: sessions,
      runtime: runtime,
      project: project,
      viewer: ViewerViewModel(),
      controller: SimulatorController(
        project: project,
        runtime: runtime,
        run: run,
        sessions: sessions,
      ),
    );
  }

  final RunLog log;
  final RunViewModel run;
  final SessionService sessions;
  final RuntimeViewModel runtime;
  final ProjectViewModel project;
  final ViewerViewModel viewer;
  final SimulatorController controller;

  /// Checks the runtime, restores the recent projects, and applies
  /// [options].
  Future<void> init(SimulatorOptions options) async {
    await runtime.init();
    await project.init(initialDirectory: options.project);
    if (options.run) unawaited(controller.startWhenReady());
  }

  /// Shuts the run's runner down before killing the tool, which would
  /// leave the runner behind.
  void dispose() {
    if (run.isActive) controller.shutDownRunner(run.appName);
    run.dispose();
    sessions.dispose();
    runtime.dispose();
    project.dispose();
    viewer.dispose();
    log.dispose();
  }
}
