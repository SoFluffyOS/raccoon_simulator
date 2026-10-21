import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A compact icon button with a tooltip; faded and inert without [onTap].
class IconToolButton extends StatelessWidget {
  const IconToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;

  /// Shown on hover and read out.
  final String tooltip;

  final VoidCallback? onTap;

  /// Draws the button as the chosen one of a group.
  final bool selected;

  /// The icon's colour, such as a warning; the text colour otherwise.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint = switch ((enabled, selected)) {
      (false, _) => Palette.textFaint,
      (true, true) => Palette.accent,
      (true, false) => color ?? Palette.text,
    };
    return Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      selected: selected,
      child: Tappable(
        tooltip: tooltip,
        onTap: onTap,
        enableHover: enabled,
        enableHoverOverlay: enabled,
        hoverOverlayBorderRadius: Spacing.d6,
        child: Container(
          width: Spacing.d32,
          height: Spacing.d32,
          decoration: BoxDecoration(
            color: switch (selected) {
              true => Palette.accent.withValues(alpha: 0.16),
              false => FluffyColors.transparent,
            },
            borderRadius: Spacing.r6,
          ),
          child: Icon(icon, size: Spacing.d16, color: tint),
        ),
      ),
    );
  }
}
