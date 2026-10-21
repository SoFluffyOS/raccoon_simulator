import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A thin vertical line between groups of toolbar buttons.
class ToolbarSeparator extends StatelessWidget {
  const ToolbarSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.d1,
      height: Spacing.d16,
      margin: EdgeInsets.symmetric(horizontal: Spacing.d6),
      color: Palette.border,
    );
  }
}
