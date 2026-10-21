import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';

/// One fact in the status bar.
class StatusItem extends StatelessWidget {
  const StatusItem(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.d16),
      child: Text(text, style: Typography.caption),
    );
  }
}
