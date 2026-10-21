import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/widgets/button_tone.dart';

/// A flat text button with hover and press feedback; disabled without
/// [onTap].
class ToolButton extends StatefulWidget {
  const ToolButton({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.tone = ButtonTone.plain,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;

  /// Draws the button as the chosen one of a group.
  final bool selected;
  final ButtonTone tone;

  /// Read out instead of [label], such as a preset's full size.
  final String? semanticLabel;

  @override
  State<ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<ToolButton> {
  var _hovered = false;
  var _pressed = false;

  bool get _enabled => widget.onTap != null;

  Color get _background {
    final base = switch ((widget.tone, widget.selected)) {
      (ButtonTone.primary, _) => Palette.accent.withValues(alpha: 0.18),
      (ButtonTone.danger, _) => Palette.error.withValues(alpha: 0.16),
      (ButtonTone.plain, true) => Palette.surfaceRaised,
      (ButtonTone.plain, false) => const Color(0x00000000),
    };
    if (!_enabled) return base;
    final overlay = switch ((_pressed, _hovered)) {
      (true, _) => Palette.pressed,
      (false, true) => Palette.hover,
      (false, false) => null,
    };
    if (overlay == null) return base;
    return Color.alphaBlend(overlay, base);
  }

  Color get _foreground {
    if (!_enabled) return Palette.textFaint;
    return switch ((widget.tone, widget.selected)) {
      (ButtonTone.primary, _) => Palette.accent,
      (ButtonTone.danger, _) => Palette.error,
      (ButtonTone.plain, true) => Palette.text,
      (ButtonTone.plain, false) => Palette.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: switch (_enabled) {
          true => SystemMouseCursors.click,
          false => SystemMouseCursors.basic,
        },
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.d10,
              vertical: Spacing.d6,
            ),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(Spacing.d6),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              style: Typography.body.copyWith(
                color: _foreground,
                fontWeight: switch (widget.selected) {
                  true => FontWeight.w600,
                  false => FontWeight.w500,
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
