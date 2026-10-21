/// Where a `flutter run` session is.
enum RunPhase {
  /// No `flutter run` process.
  idle,

  /// The process is up; building, installing or launching.
  starting,

  /// `app.started` arrived; reload and restart work.
  running,

  /// Stop was asked for; waiting for the process to exit.
  stopping,
}
