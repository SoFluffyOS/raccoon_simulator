import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:simulator/utils/utils.dart';

/// The bottom bar: run state, launch and reload timings, and the runner.
class StatusBarFrame extends StatelessWidget {
  const StatusBarFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<RunViewModel, RunPhase>(
      (viewModel) => viewModel.phase,
    );
    final progress = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.progress,
    );
    final launch = context.select<RunViewModel, Duration?>(
      (viewModel) => viewModel.launchTime,
    );
    final restart = context.select<RunViewModel, RestartResult?>(
      (viewModel) => viewModel.lastRestart,
    );
    final runName = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.appName,
    );
    final projectName = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.project?.appName,
    );
    final name = context.select<SessionService, String?>(
      (service) => service.shownApp(running: runName, project: projectName),
    );
    final pid = context.select<SessionService, int?>(
      (service) => switch (name) {
        final name? => service.session(name)?.pid,
        null => null,
      },
    );
    final private = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.privateSockets,
    );
    final ready = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.isReady,
    );
    context
      ..select<ProjectViewModel, bool>((viewModel) => viewModel.project != null)
      ..select<RuntimeViewModel, bool>((viewModel) => viewModel.settingUp);
    final blocker = context.read<SimulatorController>().runBlocker;
    final (color, label) = switch (phase) {
      RunPhase.idle => switch ((pid, ready)) {
        (_?, _) => (Palette.ok, 'Showing ${name ?? 'the app'}'),
        (null, true) => (
          Palette.textFaint,
          'Ready: run your app on the Raccoon device',
        ),
        (null, false) => (Palette.textFaint, blocker ?? 'Ready'),
      },
      RunPhase.starting => (Palette.warning, progress ?? 'Starting'),
      RunPhase.running => (Palette.ok, 'Running'),
      RunPhase.stopping => (Palette.warning, 'Stopping'),
    };
    return Container(
      height: Spacing.d28,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.d12),
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(top: BorderSide(color: Palette.border)),
      ),
      child: Row(
        children: [
          StatusDot(color: color),
          const SizedBox(width: Spacing.d8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typography.caption,
            ),
          ),
          if (launch case final launch?)
            StatusItem('Launch ${formatDuration(launch)}'),
          if (restart case final restart?)
            StatusItem(
              '${restart.kind.label} ${formatDuration(restart.duration)}'
              '${switch (restart.succeeded) {
                true => '',
                false => ' (failed)',
              }}',
            ),
          if (pid case final pid?) StatusItem('Runner pid $pid'),
          StatusItem(switch (private) {
            true => 'Private sockets',
            false => 'Shared sockets',
          }),
        ],
      ),
    );
  }
}
