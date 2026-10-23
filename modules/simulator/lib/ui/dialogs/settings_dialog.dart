import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:simulator/utils/utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Everything beyond the toolbar: setup and its checks, a project to run
/// from the simulator, socket privacy, and the log.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static const closeKey = ValueKey('settings-close');

  static Future<void> show(BuildContext context) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close settings',
    barrierColor: FluffyColors.barrier,
    transitionDuration: FluffyDurations.dialogTransition,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => const SettingsDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final width = switch (context.screenSize.isSmallDevice) {
      true => MediaQuery.sizeOf(context).width,
      false => Spacing.d440 + Spacing.d80,
    };
    return DialogCard(
      maxWidth: width,
      title: Row(
        children: [
          const Expanded(child: Text('Settings')),
          IconToolButton(
            key: closeKey,
            icon: LucideIcons.x,
            tooltip: 'Close',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RuntimeSettingsFrame(),
            ProjectSettingsFrame(),
            LogSettingsFrame(),
          ],
        ),
      ),
    );
  }
}
