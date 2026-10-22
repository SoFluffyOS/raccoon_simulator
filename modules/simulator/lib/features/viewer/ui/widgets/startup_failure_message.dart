import 'package:flutter/widgets.dart';
import 'package:raccoon/raccoon.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Where the app would be when it stopped before its first frame: what it
/// died of, the plugin to blame when the report names one, and the plugin
/// report itself a tap away.
class StartupFailureMessage extends StatefulWidget {
  const StartupFailureMessage({
    super.key,
    required this.name,
    required this.failure,
    this.plugins,
  });

  final String name;
  final StartupFailure failure;

  /// The runner's plugin report, when it sent one.
  final Plugins? plugins;

  @override
  State<StartupFailureMessage> createState() => _StartupFailureMessageState();
}

class _StartupFailureMessageState extends State<StartupFailureMessage> {
  var _showReport = false;

  @override
  Widget build(BuildContext context) {
    final typography = context.fluffyTheme.typography;
    final failure = widget.failure;
    final reports = widget.plugins?.plugins ?? const <PluginReport>[];
    final what = switch (failure.exception) {
      final exception? => exception,
      null => 'Nothing answered ${failure.channels.join(', ')}.',
    };
    final why = switch (failure.exception) {
      _ when failure.plugins.isNotEmpty =>
        'A plugin with nothing behind it on this host gets no reply, and '
            'the app did not catch the error.',
      null => 'A plugin call got no reply, and the app has not drawn since.',
      _ =>
        'Nothing caught it before the first frame. The run\'s log has '
            'the stack.',
    };
    // A long plugin report scrolls rather than spilling out.
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Spacing.d440),
          child: Padding(
            padding: EdgeInsets.all(Spacing.d24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.name} stopped before its first frame',
                  style: typography.headline6.copyWith(color: Palette.text),
                  textAlign: TextAlign.center,
                ),
                Spacing.v8,
                Text(
                  what,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: typography.base2.copyWith(
                    fontWeight: FontWeight.normal,
                    color: Palette.error,
                  ),
                ),
                for (final hint in failure.hints) ...[
                  Spacing.v8,
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: typography.base2.copyWith(color: Palette.text),
                  ),
                ],
                Spacing.v8,
                Text(
                  why,
                  textAlign: TextAlign.center,
                  style: typography.caption2.copyWith(color: Palette.textMuted),
                ),
                if (reports.isNotEmpty) ...[
                  Spacing.v16,
                  Button(
                    variant: ButtonVariant.secondary,
                    label: switch (_showReport) {
                      true => 'Hide report',
                      false => 'Plugin report',
                    },
                    onPressed: () => setState(() => _showReport = !_showReport),
                  ),
                ],
                if (_showReport)
                  for (final report in reports) ...[
                    Spacing.v4,
                    Text(
                      _line(report),
                      textAlign: TextAlign.center,
                      style: typography.caption2.copyWith(
                        color: Palette.textMuted,
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One plugin of the report, in words.
  static String _line(PluginReport report) => switch (report.state) {
    PluginState.PLUGIN_STATE_LOADED => '${report.name}: loaded',
    PluginState.PLUGIN_STATE_BUILT_IN =>
      '${report.name}: answered by the runner',
    PluginState.PLUGIN_STATE_NO_HOST ||
    PluginState.PLUGIN_STATE_FAILED ||
    PluginState.PLUGIN_STATE_BUILT_NOTHING => StartupFailure.hintFor(report),
    _ => switch (report.detail) {
      '' => report.name,
      final detail => '${report.name}: $detail',
    },
  };
}
