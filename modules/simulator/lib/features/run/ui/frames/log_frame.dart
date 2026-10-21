import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/run/ui/widgets/widgets.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// The log panel: the tool's events, the app's output and setup steps,
/// newest at the bottom.
class LogFrame extends StatelessWidget {
  const LogFrame({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<RunLog, int>((log) => log.revision);
    final log = context.read<RunLog>();
    final count = log.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(top: BorderSide(color: Palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.d16,
              Spacing.d4,
              Spacing.d8,
              Spacing.d4,
            ),
            child: Row(
              children: [
                const Expanded(child: Text('LOG', style: Typography.section)),
                ToolButton(
                  label: 'Copy',
                  onTap: switch (count) {
                    0 => null,
                    _ => () => Clipboard.setData(ClipboardData(text: log.text)),
                  },
                ),
                ToolButton(
                  label: 'Clear',
                  onTap: switch (count) {
                    0 => null,
                    _ => log.clear,
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(
                Spacing.d16,
                0,
                Spacing.d16,
                Spacing.d8,
              ),
              itemCount: count,
              itemBuilder: (context, index) =>
                  LogLineView(line: log.lineAt(count - 1 - index)),
            ),
          ),
        ],
      ),
    );
  }
}
