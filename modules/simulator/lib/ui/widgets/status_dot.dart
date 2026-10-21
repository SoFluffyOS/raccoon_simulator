import 'package:flutter/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A small filled circle in a status colour.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.d8,
      height: Spacing.d8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
