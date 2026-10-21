import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// What the viewport says when there is no app to show.
class ViewerMessage extends StatelessWidget {
  const ViewerMessage({
    super.key,
    required this.title,
    this.detail,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? detail;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final typography = context.fluffyTheme.typography;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Spacing.d440),
        child: Padding(
          padding: EdgeInsets.all(Spacing.d24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: typography.headline6.copyWith(color: Palette.text),
                textAlign: TextAlign.center,
              ),
              if (detail case final detail?) ...[
                Spacing.v8,
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: typography.base2.copyWith(
                    fontWeight: FontWeight.normal,
                    color: switch (isError) {
                      true => Palette.error,
                      false => Palette.textMuted,
                    },
                  ),
                ),
              ],
              if (actionLabel case final label?) ...[
                Spacing.v16,
                Button(
                  variant: ButtonVariant.primary,
                  label: label,
                  enable: onAction != null,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
