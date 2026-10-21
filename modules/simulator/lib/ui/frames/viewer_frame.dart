import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/dialogs/dialogs.dart';

/// The viewport: the shown app's live session at the chosen size, or what
/// stands in its way. The shown app is the simulator's own run, else the
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

/// What the viewport tells about setup while no app shows.
typedef _Setup = ({bool running, CheckKind? step, bool needed, String? error});
