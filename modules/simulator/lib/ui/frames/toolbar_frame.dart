import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// The top bar: the shown app, Run or Stop, hot reload, hot restart, and the
/// size presets. Reload and restart are for runs started here; an app run
/// from an editor reloads from the editor.
class ToolbarFrame extends StatelessWidget {
  const ToolbarFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final runName = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.appName,
    );
    final projectName = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.project?.appName,
    );
    final shownName = context.select<SessionService, String?>(
      (service) => service.shownApp(running: runName, project: projectName),
    );
    final phase = context.select<RunViewModel, RunPhase>(
      (viewModel) => viewModel.phase,
    );
    final canRestart = context.select<RunViewModel, bool>(
      (viewModel) => viewModel.canRestart,
    );
    final restarting = context.select<RunViewModel, RestartKind?>(
      (viewModel) => viewModel.restarting,
    );
    context
      ..select<RuntimeViewModel, bool>((viewModel) => viewModel.isReady)
      ..select<RuntimeViewModel, FlutterSdk?>((viewModel) => viewModel.sdk);
    final controller = context.read<SimulatorController>();
    final run = context.read<RunViewModel>();
    final canRun = controller.runBlocker == null;
    return Container(
      height: Spacing.d40 + Spacing.d8,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.d12),
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(bottom: BorderSide(color: Palette.border)),
      ),
      child: Row(
        children: [
          Text(shownName ?? 'Raccoon Simulator', style: Typography.title),
          const SizedBox(width: Spacing.d16),
          switch (phase) {
            RunPhase.idle => ToolButton(
              label: 'Run',
              tone: ButtonTone.primary,
              onTap: switch (canRun) {
                true => controller.start,
                false => null,
              },
            ),
            RunPhase.starting || RunPhase.running => ToolButton(
              label: 'Stop',
              tone: ButtonTone.danger,
              onTap: controller.stop,
            ),
            RunPhase.stopping => const ToolButton(label: 'Stopping…'),
          },
          const SizedBox(width: Spacing.d4),
          for (final kind in RestartKind.values)
            ToolButton(
              label: switch (restarting == kind) {
                true => '${kind.label}…',
                false => kind.label,
              },
              onTap: switch (canRestart) {
                true => () => run.restart(kind),
                false => null,
              },
            ),
          const Spacer(),
          const PresetBarFrame(),
        ],
      ),
    );
  }
}
