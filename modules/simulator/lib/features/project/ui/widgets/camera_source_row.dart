import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// What the project's camera shows: a picture or video, or the runner's test
/// pattern; the image button picks one, × goes back to the pattern.
class CameraSourceRow extends StatelessWidget {
  const CameraSourceRow({
    super.key,
    required this.source,
    this.onPick,
    this.onClear,
  });

  static const pickKey = ValueKey('camera-source-pick');
  static const clearKey = ValueKey('camera-source-clear');

  /// The picture's or video's path, or null for the test pattern.
  final String? source;

  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const Icon(LucideIcons.camera),
      title: switch (source) {
        final source? => p.basename(source),
        null => 'Test pattern',
      },
      subtitle: switch (source) {
        final source? => source,
        null => 'What the camera shows; next run',
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconToolButton(
            key: pickKey,
            icon: LucideIcons.image,
            tooltip: 'Choose what the camera shows',
            onTap: onPick,
          ),
          IconToolButton(
            key: clearKey,
            icon: LucideIcons.x,
            tooltip: 'Back to the test pattern',
            onTap: switch (source) {
              null => null,
              _ => onClear,
            },
          ),
        ],
      ),
    );
  }
}
