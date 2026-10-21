import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';

/// A small filled circle in a status colour.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.statusDot,
      height: Spacing.statusDot,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
