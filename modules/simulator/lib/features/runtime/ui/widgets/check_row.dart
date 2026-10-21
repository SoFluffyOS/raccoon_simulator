import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// One runtime check: status, what was found, and a button per fix.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.check, this.fixing, this.onFix});

  final RuntimeCheck check;

  /// The fix of this check that is running, if any.
  final FixKind? fixing;

  /// Runs a fix; null while another fix runs.
  final void Function(FixKind fix)? onFix;

  @override
  Widget build(BuildContext context) {
    final typography = context.fluffyTheme.typography;
    final color = switch (check.status) {
      CheckStatus.ok => Palette.ok,
      CheckStatus.warning => Palette.warning,
      CheckStatus.missing => Palette.error,
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.d4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: Spacing.d6, right: Spacing.d8),
            child: StatusDot(color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.kind.label, style: typography.base2),
                Text(
                  check.detail,
                  style: typography.caption2.copyWith(
                    color: Palette.textMuted,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (final fix in check.fixes) ...[
            Spacing.h8,
            Button(
              variant: ButtonVariant.ghost,
              label: switch (fixing == fix) {
                true => 'Working…',
                false => fix.label,
              },
              enable: fixing == null && onFix != null,
              onPressed: switch (onFix) {
                null => null,
                final onFix => () => onFix(fix),
              },
            ),
          ],
        ],
      ),
    );
  }
}
