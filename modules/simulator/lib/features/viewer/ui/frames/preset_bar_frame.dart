import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/features/viewer/models/models.dart';
import 'package:simulator/features/viewer/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// The size presets, the selected one highlighted.
class PresetBarFrame extends StatelessWidget {
  const PresetBarFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.select<ViewerViewModel, SizePreset>(
      (viewModel) => viewModel.preset,
    );
    final viewModel = context.read<ViewerViewModel>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final preset in SizePreset.all)
          ToolButton(
            label: preset.name,
            semanticLabel: preset.toString(),
            selected: preset == selected,
            onTap: () => viewModel.select(preset),
          ),
      ],
    );
  }
}
