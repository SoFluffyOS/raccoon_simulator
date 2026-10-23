import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/project/models/models.dart';
import 'package:simulator/features/project/ui/widgets/widgets.dart';
import 'package:simulator/features/project/view_models/view_models.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The settings' project block, for running an app from the simulator
/// instead of an editor: open a folder, or pick a recent one, and choose what
/// its camera shows. Locked while a run is active.
class ProjectSettingsFrame extends StatelessWidget {
  const ProjectSettingsFrame({super.key});

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
    final cameraSource = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.cameraSource,
    );
    final locked = context.select<RunViewModel, bool>(
      (viewModel) => viewModel.isActive,
    );
    final viewModel = context.read<ProjectViewModel>();
    final caption = context.fluffyTheme.typography.caption2.copyWith(
      color: Palette.textMuted,
    );
    return SettingsSection(
      title: 'Run from the simulator',
      actions: [
        Button(
          variant: ButtonVariant.ghost,
          label: 'Open…',
          enable: !locked,
          onPressed: viewModel.pick,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Optional. Runs from your editor show up on their own; open a '
            'project here to run it with the toolbar instead.',
            style: caption,
          ),
          if (error case final error?) ...[
            Spacing.v4,
            Text(error, style: caption.copyWith(color: Palette.error)),
          ],
          if (project != null) ...[
            Spacing.v8,
            CameraSourceRow(
              source: cameraSource,
              onPick: switch (locked) {
                true => null,
                false => viewModel.pickCameraSource,
              },
              onClear: switch (locked) {
                true => null,
                false => viewModel.clearCameraSource,
              },
            ),
          ],
          Spacing.v8,
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
