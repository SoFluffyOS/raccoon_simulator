import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/widgets/widgets.dart';

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Spacing.messageWidth),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.d24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Typography.title, textAlign: TextAlign.center),
              if (detail case final detail?)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.d8),
                  child: Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: Typography.body.copyWith(
                      color: switch (isError) {
                        true => Palette.error,
                        false => Palette.textMuted,
                      },
                    ),
                  ),
                ),
              if (actionLabel case final label?)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.d16),
                  child: ToolButton(
                    label: label,
                    tone: ButtonTone.primary,
                    onTap: onAction,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
