import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/project/models/models.dart';
import 'package:simulator/features/project/ui/widgets/widgets.dart';
import 'package:simulator/features/project/view_models/view_models.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// The sidebar's project block, for running an app from the simulator
/// instead of an editor: open a folder, or pick a recent one. Locked while a
/// run is active.
class ProjectFrame extends StatelessWidget {
  const ProjectFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final project = context.select<ProjectViewModel, SimulatorProject?>(
      (viewModel) => viewModel.project,
    );
    final recent = context.select<ProjectViewModel, List<String>>(
      (viewModel) => viewModel.recent,
    );
    final error = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.error,
    );
    final locked = context.select<RunViewModel, bool>(
      (viewModel) => viewModel.isActive,
    );
    final viewModel = context.read<ProjectViewModel>();
    return PanelSection(
      title: 'Project',
      actions: [
        ToolButton(
          label: 'Open…',
          onTap: switch (locked) {
            true => null,
            false => viewModel.pick,
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project == null && recent.isEmpty)
            const Text(
              'Optional: open a Flutter app here to run it from the '
              'simulator. Runs from your editor show up on their own.',
              style: Typography.caption,
            ),
          if (error case final error?)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.d8),
              child: Text(
                error,
                style: Typography.caption.copyWith(color: Palette.error),
              ),
            ),
          for (final directory in recent)
            RecentProjectRow(
              key: ValueKey(directory),
              directory: directory,
              current: directory == project?.directory,
              onOpen: switch (locked) {
                true => null,
                false => () => viewModel.open(directory),
              },
              onForget: switch (locked) {
                true => null,
                false => () => viewModel.forget(directory),
              },
            ),
        ],
      ),
    );
  }
}
