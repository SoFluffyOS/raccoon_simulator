/// A duration for the status bar: milliseconds below a second, else seconds
/// with one decimal.
String formatDuration(Duration duration) {
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) return '$milliseconds ms';
  return '${(milliseconds / 1000).toStringAsFixed(1)} s';
}
