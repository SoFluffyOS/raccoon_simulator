import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// One recently opened folder: its name and path; tap opens it, × forgets it.
class RecentProjectRow extends StatelessWidget {
  const RecentProjectRow({
    super.key,
    required this.directory,
    required this.current,
    this.onOpen,
    this.onForget,
  });

  final String directory;

  /// Whether this is the open project.
  final bool current;

  final VoidCallback? onOpen;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (current) {
          true => Palette.surface,
          false => FluffyColors.transparent,
        },
        borderRadius: Spacing.r6,
      ),
      child: ListItem(
        title: p.basename(directory),
        subtitle: directory,
        onTap: onOpen,
        trailing: IconToolButton(
          icon: LucideIcons.x,
          tooltip: 'Forget',
          onTap: onForget,
        ),
      ),
    );
  }
}
