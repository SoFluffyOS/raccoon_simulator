import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';

/// An on/off switch; disabled without [onChanged].
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({
    super.key,
    required this.value,
    required this.label,
    this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final track = switch ((value, enabled)) {
      (true, true) => Palette.accent,
      (true, false) => Palette.accent.withValues(alpha: 0.4),
      (false, _) => Palette.border,
    };
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: switch (enabled) {
          true => SystemMouseCursors.click,
          false => SystemMouseCursors.basic,
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: switch (onChanged) {
            final changed? => () => changed(!value),
            null => null,
          },
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: Spacing.d28,
                height: Spacing.d16,
                padding: const EdgeInsets.all(Spacing.d2),
                alignment: switch (value) {
                  true => Alignment.centerRight,
                  false => Alignment.centerLeft,
                },
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(Spacing.d8),
                ),
                child: Container(
                  width: Spacing.d12,
                  height: Spacing.d12,
                  decoration: const BoxDecoration(
                    color: Palette.text,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.d8),
              Expanded(child: Text(label, style: Typography.body)),
            ],
          ),
        ),
      ),
    );
  }
}
