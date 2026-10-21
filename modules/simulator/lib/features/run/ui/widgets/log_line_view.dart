import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/run/models/models.dart';

/// One log line, tinted by where it came from.
class LogLineView extends StatelessWidget {
  const LogLineView({super.key, required this.line});

  final LogLine line;

  @override
  Widget build(BuildContext context) {
    final color = switch (line.source) {
      LogSource.app => Palette.text,
      LogSource.tool => Palette.textMuted,
      LogSource.setup => Palette.accent,
      LogSource.error => Palette.error,
    };
    return Text(line.text, style: Typography.mono.copyWith(color: color));
  }
}
