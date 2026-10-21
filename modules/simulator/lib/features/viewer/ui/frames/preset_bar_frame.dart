import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:simulator/features/viewer/models/models.dart';
import 'package:simulator/features/viewer/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:simulator/utils/utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The size presets as icon buttons, the selected one highlighted. A narrow
/// window gets one button that steps through them.
class PresetBarFrame extends StatelessWidget {
  const PresetBarFrame({super.key});

  /// The button for [preset], for tests.
  static ValueKey<String> keyOf(SizePreset preset) =>
      ValueKey('preset-${preset.name}');

  static IconData iconOf(SizePreset preset) => switch (preset) {
    SizePreset.phone => LucideIcons.smartphone,
    SizePreset.tablet => LucideIcons.tablet,
    SizePreset.desktop => LucideIcons.monitor,
    _ => LucideIcons.maximize,
  };

  @override
  Widget build(BuildContext context) {
    final selected = context.select<ViewerViewModel, SizePreset>(
      (viewModel) => viewModel.preset,
    );
    final viewModel = context.read<ViewerViewModel>();
    if (context.screenSize.isSmallDevice) {
      return IconToolButton(
        key: const ValueKey('preset-next'),
        icon: iconOf(selected),
        tooltip: '$selected, tap for ${selected.next.name}',
        onTap: () => viewModel.select(selected.next),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final preset in SizePreset.all)
          IconToolButton(
            key: keyOf(preset),
            icon: iconOf(preset),
            tooltip: preset.toString(),
            selected: preset == selected,
            onTap: () => viewModel.select(preset),
          ),
      ],
    );
  }
}
