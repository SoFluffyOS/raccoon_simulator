import 'dart:async';

import 'package:simulator/features/features.dart';

/// Ties the features together for the actions that need more than one: run
/// the chosen project with the runtime's environment, and stop it so its
/// runner goes too.
final class SimulatorController {
  SimulatorController({
    required this.project,
    required this.runtime,
    required this.run,
    required this.sessions,
  });

  final ProjectViewModel project;
  final RuntimeViewModel runtime;
  final RunViewModel run;
  final SessionService sessions;

  /// Why Run is unavailable, or null when it can start.
  String? get runBlocker {
    if (run.isActive) return 'Already running';
    if (runtime.sdk == null) return 'No Flutter SDK found';
    if (runtime.settingUp) return 'Setting up the runtime';
    if (!runtime.isReady) return 'Fix the runtime setup first';
    if (project.project == null) return 'Open a Flutter project first';
    return null;
  }

  Future<void> start() async {
    final chosen = project.project;
    final sdk = runtime.sdk;
    if (runBlocker != null || chosen == null || sdk == null) return;
    sessions.expectFresh(chosen.appName, since: DateTime.now());
    // A run that ends before its runner came (stopped, a failed build)
    // gives the app back to a runner already there.
    void ended() {
      if (run.isActive) return;
      run.removeListener(ended);
      sessions.cancelFresh(chosen.appName);
    }

    run.addListener(ended);
    await run.run(
      directory: chosen.directory,
      appName: chosen.appName,
      flutter: sdk.flutter,
      environment: {...runtime.runEnvironment, ...project.runEnvironment},
    );
  }

  /// Stops the run, then asks a runner the tool left behind to shut down:
  /// the tool does not stop its runner when it is killed.
  Future<void> stop() async {
    final name = run.appName;
    await run.stop();
    shutDownRunner(name);
  }

  /// Asks [name]'s runner to exit, if a session to it is open.
  void shutDownRunner(String? name) {
    if (name == null) return;
    if (sessions.session(name) case final session?) session.client.shutdown();
  }

  /// Starts the project as soon as it and the runtime are ready, for
  /// `--run` on the command line. Gives up [timeout] after the runtime's
  /// setup is done: a first one downloads and may build for minutes.
  Future<void> startWhenReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    var deadline = DateTime.now().add(timeout);
    while (runBlocker != null) {
      if (run.isActive) return;
      if (runtime.settingUp) {
        deadline = DateTime.now().add(timeout);
      }
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await start();
  }
}
