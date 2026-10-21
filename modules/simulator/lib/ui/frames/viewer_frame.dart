import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';

/// The viewport: the live session of the project's app at the chosen size,
/// or what stands in its way.
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
    final name = runName ?? projectName;
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
    final directory = context.select<SessionService, String?>(
      (service) => service.directory,
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
  }) {
    if (name == null) {
      return const ViewerMessage(
        title: 'No project',
        detail: 'Open a Flutter project from the sidebar, then press Run.',
      );
    }
    if (session case final session?) {
      return AppViewport(connection: session.client, preset: preset);
    }
    if (refused) {
      return ViewerMessage(
        title: 'The runner is taken',
        detail:
            'Another client, such as an IDE, is connected to '
            "$name's runner, and a runner serves one client at a time. Close "
            'it there, or turn on private runner sockets and run again.',
        isError: true,
        actionLabel: 'Retry',
        onAction: context.read<SessionService>().retry,
      );
    }
    return switch (phase) {
      RunPhase.idle => ViewerMessage(
        title: name,
        detail: error ?? 'Press Run to start it on the Raccoon runtime.',
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
}
