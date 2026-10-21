import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// One runtime check: status, what was found, and its fix button.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.check,
    this.fixing = false,
    this.onFix,
  });

  final RuntimeCheck check;

  /// Whether this check's fix is running.
  final bool fixing;

  /// Runs the fix; null while another fix runs.
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final color = switch (check.status) {
      CheckStatus.ok => Palette.ok,
      CheckStatus.warning => Palette.warning,
      CheckStatus.missing => Palette.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.d4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Spacing.d6, right: Spacing.d8),
            child: StatusDot(color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.kind.label, style: Typography.body),
                Text(
                  check.detail,
                  style: Typography.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (check.fixLabel case final label?)
            ToolButton(
              label: switch (fixing) {
                true => 'Working…',
                false => label,
              },
              tone: ButtonTone.primary,
              onTap: switch (fixing) {
                true => null,
                false => onFix,
              },
            ),
        ],
      ),
    );
  }
}
