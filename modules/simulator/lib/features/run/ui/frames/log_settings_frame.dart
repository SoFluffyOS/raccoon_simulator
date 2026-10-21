import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The settings' log block: the tool's and the app's output stay out of the
/// window, one click away for a bug report.
class LogSettingsFrame extends StatelessWidget {
  const LogSettingsFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final length = context.select<RunLog, int>((log) => log.length);
    final log = context.read<RunLog>();
    return SettingsSection(
      title: 'Log',
      actions: [
        Button(
          variant: ButtonVariant.ghost,
          label: 'Copy',
          enable: length > 0,
          onPressed: () => Clipboard.setData(ClipboardData(text: log.text)),
        ),
        Button(
          variant: ButtonVariant.ghost,
          label: 'Clear',
          enable: length > 0,
          onPressed: log.clear,
        ),
      ],
      child: Text(
        switch (length) {
          0 => 'Nothing logged yet.',
          1 => '1 line from setup, the tool and the app.',
          _ => '$length lines from setup, the tool and the app.',
        },
        style: context.fluffyTheme.typography.caption2.copyWith(
          color: Palette.textMuted,
        ),
      ),
    );
  }
}
