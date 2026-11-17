import 'dart:async';

import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/app/simulator_options.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';
import 'package:simulator/utils/utils.dart';

/// Every view model and service of one simulator window, wired together.
final class SimulatorServices {
  SimulatorServices._({
    required this.log,
    required this.run,
    required this.sessions,
    required this.runtime,
    required this.project,
    required this.viewer,
    required this.board,
    required this.controller,
    required this.chrome,
    required this.agentRuns,
    required this.control,
    required this.visibility,
  });

  factory SimulatorServices.create({
    required HostInfo host,
    required SettingsStore settings,
    FlutterRunStarter? startFlutter,
    DirectoryPicker? pickDirectory,
  }) {
    final log = RunLog();
    // Where a `flutter run -d raccoon` from any editor puts its runner; always
    // followed, next to the folder of the simulator's own runs.
    final shared = RunnerSockets.forHost(
      operatingSystem: host.operatingSystem,
      environment: host.environment,
      temporaryDirectory: host.temporaryDirectory,
      private: false,
    );
    final project = ProjectViewModel(
      settings: settings,
      pickDirectory: pickDirectory,
    );
    // Frames come as GPU buffers where the view has a native side to show
    // them through.
    final sessions = SessionService(
      ownsProject: (name) => project.project?.appName == name,
      connect: (endpoint, {yields = false, claims = false}) =>
          RunnerClient.connect(
            endpoint,
            yields: yields,
            claims: claims,
            composes: true,
            gpuBuffers: HostGpuTextures.forHost() != null,
            // Pixel frames, where they come, into buffers the client keeps:
            // the view copies what it shows when it decodes.
            reusePixels: true,
          ),
      // The plugins with no implementation on the host answer as a phone
      // would, permissions granted.
      serve: (client) {
        const IdePlatformChannels().register(client);
        PluginStubs().register(client);
      },
    );
    final runtime = RuntimeViewModel(
      host: host,
      settings: settings,
      doctor: RuntimeDoctor(host: host),
      fixer: RuntimeFixer(host: host),
      onLine: (line) => log.add(LogSource.setup, line),
      onSocketsChanged: (sockets) =>
          sessions.follow([sockets.discovery, shared.discovery]),
    );
    final run = RunViewModel(log: log, start: startFlutter);
    final agentRuns = AgentRuns(log: log, start: startFlutter);
    final viewer = ViewerViewModel();
    final board = BoardViewModel(
      settings: settings,
      sizes: AppSizes.forHost(host.environment),
    );
    final visibility = WindowVisibility(sessions: sessions);
    final controller = SimulatorController(
      project: project,
      runtime: runtime,
      run: run,
      sessions: sessions,
      agentRuns: agentRuns,
    );
    return SimulatorServices._(
      log: log,
      run: run,
      sessions: sessions,
      runtime: runtime,
      project: project,
      viewer: viewer,
      board: board,
      chrome: WindowChrome(toolbarIsTitleBar: host.operatingSystem == 'macos'),
      controller: controller,
      agentRuns: agentRuns,
      control: SimulatorControlHost(
        sessions: sessions,
        hostRun: run,
        agentRuns: agentRuns,
        runtime: runtime,
        board: board,
        viewer: viewer,
        log: log,
        environment: host.environment,
        stopHostRun: controller.stop,
        visibility: visibility,
      ),
      visibility: visibility,
    );
  }

  final RunLog log;
  final RunViewModel run;
  final SessionService sessions;
  final RuntimeViewModel runtime;
  final ProjectViewModel project;
  final ViewerViewModel viewer;
  final BoardViewModel board;
  final SimulatorController controller;
  final WindowChrome chrome;

  /// The runs agents started through the control endpoint.
  final AgentRuns agentRuns;

  /// What the control endpoint serves.
  final SimulatorControlHost control;

  /// Tells the apps whether the window shows.
  final WindowVisibility visibility;

  RaccoonControlServer? _server;
  var _disposed = false;

  /// Checks the runtime and sets up what is missing, restores the recent
  /// projects, and applies [options].
  Future<void> init(SimulatorOptions options) async {
    await runtime.init();
    if (options.setUp) unawaited(runtime.setUp());
    await project.init(initialDirectory: options.project);
    await board.load(project.project?.directory);
    project.addListener(_projectChanged);
    if (options.run) unawaited(controller.startWhenReady());
    if (options.control) await _serveControl();
  }

  /// Serves [control] on the loopback interface, for this user's agents;
  /// see [RaccoonControlServer].
  Future<void> _serveControl() async {
    try {
      final server = await RaccoonControlServer.start(
        RaccoonControl(control),
        kind: control.kind,
      );
      if (_disposed) {
        await server.close();
        return;
      }
      _server = server;
      printLog('control endpoint at ${server.uri}, see ${server.file.path}');
    } on Object catch (error, stackTrace) {
      printError('the control endpoint did not start: $error', stackTrace);
    }
  }

  /// Closes the control endpoint, then stops the toolbar's run and the
  /// agents' runs, and their runners: before the process exits.
  Future<void> shutDown() async {
    final server = _server;
    _server = null;
    await server?.close();
    final names = [for (final run in agentRuns.runs) run.name];
    await Future.wait([controller.stop(), agentRuns.stopAll()]);
    for (final name in names) {
      controller.shutDownRunner(name);
    }
  }

  void _projectChanged() => unawaited(board.load(project.project?.directory));

  /// Shuts the run's runner down before killing the tool, which would
  /// leave the runner behind.
  void dispose() {
    _disposed = true;
    unawaited(_server?.close());
    if (run.isActive) controller.shutDownRunner(run.appName);
    for (final agentRun in agentRuns.runs) {
      controller.shutDownRunner(agentRun.name);
    }
    run.dispose();
    agentRuns.dispose();
    visibility.dispose();
    sessions.dispose();
    runtime.dispose();
    project.dispose();
    viewer.dispose();
    board.dispose();
    chrome.dispose();
    log.dispose();
  }
}
