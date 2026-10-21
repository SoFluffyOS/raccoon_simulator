/// What the runtime needs before `flutter run -d raccoon` works.
enum CheckKind {
  flutter('Flutter SDK'),
  runner('Runner binary'),
  engine('Engine runtime'),
  customDevices('Custom devices enabled'),
  device('Raccoon device registered');

  const CheckKind(this.label);

  final String label;
}

enum CheckStatus {
  ok,

  /// Works, but not the way this checkout would set it up.
  warning,

  missing,
}

/// The result of one check, with the fix to offer when there is one.
final class RuntimeCheck {
  const RuntimeCheck({
    required this.kind,
    required this.status,
    required this.detail,
    this.fixLabel,
  });

  final CheckKind kind;
  final CheckStatus status;

  /// What was found, or what is missing.
  final String detail;

  /// The button that fixes it, or null when there is nothing to press.
  final String? fixLabel;

  bool get passes => status != CheckStatus.missing;
}
