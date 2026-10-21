/// Where a log line came from.
enum LogSource {
  /// The Flutter tool: progress, daemon messages, exit.
  tool,

  /// The app: its `print` output and `app.log` lines.
  app,

  /// Runtime setup: builds and installs started from the runtime panel.
  setup,

  /// Errors from any of the above.
  error,
}

/// One line in the log panel.
final class LogLine {
  const LogLine(this.source, this.text);

  final LogSource source;
  final String text;
}
