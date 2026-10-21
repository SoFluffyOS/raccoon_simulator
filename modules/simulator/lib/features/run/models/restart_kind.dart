/// The two ways to update a running app.
enum RestartKind {
  hotReload('Hot reload'),
  hotRestart('Hot restart');

  const RestartKind(this.label);

  final String label;

  /// The `fullRestart` flag `app.restart` takes.
  bool get fullRestart => switch (this) {
    RestartKind.hotReload => false,
    RestartKind.hotRestart => true,
  };
}
