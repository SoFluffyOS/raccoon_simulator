import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';

/// A titled block of the sidebar, with optional actions at the title's end.
class PanelSection extends StatelessWidget {
  const PanelSection({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.d16,
        Spacing.d16,
        Spacing.d12,
        Spacing.d8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.toUpperCase(), style: Typography.section),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: Spacing.d8),
          child,
        ],
      ),
    );
  }
}
