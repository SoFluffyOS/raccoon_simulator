import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:raccoon/raccoon.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/dialogs/dialogs.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The viewport: the shown app's live session at the chosen size, or the
/// board with every session on it when that is on, or what stands in the
/// shown app's way. The shown app is the simulator's own run, else the
/// project's app, else the app run last from an editor, see
/// [SessionService.shownApp]. With no app, it shows setup's progress.
///
/// It looks the session up by app name on every change rather than holding
/// one, so a runner that comes back under the same name after a stop or a
/// new run takes over the viewport.
class ViewerFrame extends StatelessWidget {
  const ViewerFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final boardOn = context.select<ViewerViewModel, bool>(
      (viewModel) => viewModel.boardOn,
    );
    if (boardOn) return const _Board();
    final runName = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.appName,
    );
    final projectName = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.project?.appName,
    );
    final name = context.select<SessionService, String?>(
      (service) => service.shownApp(running: runName, project: projectName),
    );
    final session = context.select<SessionService, RunnerSession?>(
      (service) => switch (name) {
        final name? => service.session(name),
        null => null,
      },
    );
    // An app that stopped before its first frame shows why instead of a
    // blank viewport; once it has drawn, the app is shown whatever it does.
    final startup = context.select<SessionService, _Startup>(
      (service) => switch (name) {
        final name? => (
          failure: service.startupFailure(name),
          plugins: service.session(name)?.client.latestPlugins,
        ),
        null => (failure: null, plugins: null),
      },
    );
    final refused = context.select<SessionService, bool>(
      (service) => switch (name) {
        final name? => service.isRefused(name),
        null => false,
      },
    );
    final phase = context.select<RunViewModel, RunPhase>(
      (viewModel) => viewModel.phase,
    );
    final progress = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.progress,
    );
    final error = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.error,
    );
    final preset = context.select<ViewerViewModel, SizePreset>(
      (viewModel) => viewModel.preset,
    );
    // The simulator's run folder comes first, see SimulatorServices.
    final directory = context.select<SessionService, String?>(
      (service) => service.directories.firstOrNull,
    );
    final setup = context.select<RuntimeViewModel, _Setup>(
      (viewModel) => (
        running: viewModel.settingUp,
        step: viewModel.fixing?.check,
        needed: viewModel.needsSetup,
        error: viewModel.fixError,
      ),
    );
    return ColoredBox(
      color: Palette.viewport,
      child: _content(
        context,
        name: name,
        session: session,
        startup: startup,
        refused: refused,
        phase: phase,
        progress: progress,
        error: error,
        preset: preset,
        directory: directory,
        setup: setup,
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required String? name,
    required RunnerSession? session,
    required _Startup startup,
    required bool refused,
    required RunPhase phase,
    required String? progress,
    required String? error,
    required SizePreset preset,
    required String? directory,
    required _Setup setup,
  }) {
    if (name == null) return _noApp(context, setup);
    if (session case final session?) {
      if (startup.failure case final failure?) {
        return StartupFailureMessage(
          // A runner of its own: a report opened for the last one starts
          // shut.
          key: ObjectKey(session.client),
          name: name,
          failure: failure,
          plugins: startup.plugins,
        );
      }
      return AppViewport(connection: session.client, preset: preset);
    }
    if (refused) {
      return ViewerMessage(
        title: 'The runner is taken',
        detail:
            'Another client, such as an IDE, is connected to '
            "$name's runner, and a runner serves one client at a time. Close "
            'it there, then retry.',
        isError: true,
        actionLabel: 'Retry',
        onAction: context.read<SessionService>().retry,
      );
    }
    return switch (phase) {
      RunPhase.idle => ViewerMessage(
        title: name,
        detail:
            error ??
            'Press Run, or run it on the Raccoon device from your editor.',
        isError: error != null,
      ),
      RunPhase.starting => ViewerMessage(
        title: 'Starting $name',
        detail: progress ?? 'Building',
      ),
      RunPhase.running => ViewerMessage(
        title: 'Waiting for the runner',
        detail: 'Looking for $name.sock in ${directory ?? 'the socket folder'}',
      ),
      RunPhase.stopping => ViewerMessage(title: 'Stopping $name'),
    };
  }

  Widget _noApp(BuildContext context, _Setup setup) {
    if (setup.running) {
      return ViewerMessage(
        title: 'Setting up Raccoon',
        detail:
            '${setup.step?.label ?? 'Checking'}… The first runner build '
            'takes a few minutes.',
      );
    }
    if (setup.needed) {
      return ViewerMessage(
        title: 'Raccoon needs setup',
        detail: setup.error ?? 'Open settings to see what is missing.',
        isError: setup.error != null,
        actionLabel: 'Open settings',
        onAction: () => SettingsDialog.show(context),
      );
    }
    return const ViewerMessage(
      title: 'Waiting for your app',
      detail:
          'Pick Raccoon in your editor\'s device list and run, or run '
          'flutter run -d raccoon in your project. The app shows up here.',
    );
  }
}

/// Every session on the board. It rebuilds when the set of names changes;
/// a session that comes back under its name keeps its frame. A run the
/// simulator starts shows from the click, as starting, until its app comes.
class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final names = context.select<SessionService, String>(
      (service) => service.sessions.map((session) => session.name).join(' '),
    );
    final sessions = context.read<SessionService>().sessions;
    final starting = context.select<RunViewModel, (String, String)?>(
      (run) => switch ((run.phase, run.appName)) {
        (RunPhase.starting, final name?) => (
          name,
          run.progress ?? 'Starting the app…',
        ),
        _ => null,
      },
    );
    final caption = context.fluffyTheme.typography.caption2;
    return ColoredBox(
      color: Palette.viewport,
      child: RaccoonBoard(
        key: ValueKey('board $names'),
        sessions: [
          for (final session in sessions)
            RaccoonBoardSession(
              name: session.name,
              connection: session.client,
              onClose: session.client.shutdown,
            ),
          if (starting case (final name, final status)
              when !sessions.any((session) => session.name == name))
            RaccoonBoardSession.starting(
              name: name,
              status: status,
              onClose: () => unawaited(context.read<RunViewModel>().stop()),
            ),
        ],
        layout: context.read<BoardViewModel>(),
        ink: Palette.textMuted,
        titleStyle: caption,
        menuColor: Palette.surface,
        empty: Text(
          'Run the project on raccoon from your editor: it shows up here. '
          'Pick its size from the frame\'s title.',
          style: context.fluffyTheme.typography.base2.copyWith(
            color: Palette.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Why the shown app stopped before its first frame, with the plugin report
/// to go with it.
typedef _Startup = ({StartupFailure? failure, Plugins? plugins});

/// What the viewport tells about setup while no app shows.
typedef _Setup = ({bool running, CheckKind? step, bool needed, String? error});
