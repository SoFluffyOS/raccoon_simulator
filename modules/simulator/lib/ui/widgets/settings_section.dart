import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A titled block of the settings dialog, with buttons beside the title.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final typography = context.fluffyTheme.typography;
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.d20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: typography.caption2.copyWith(
                    color: Palette.textFaint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: Spacing.d1,
                  ),
                ),
              ),
              for (final action in actions) ...[Spacing.h8, action],
            ],
          ),
          Spacing.v8,
          child,
        ],
      ),
    );
  }
}
