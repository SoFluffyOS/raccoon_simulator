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

/// A fix the panel offers for a check: the button's label, and what the
/// fixer does when it is pressed.
enum FixKind {
  precache(CheckKind.flutter, 'Precache'),

  /// Fetches the prebuilt runner release for this host.
  download(CheckKind.runner, 'Download'),

  /// Builds the runner from the checkout.
  build(CheckKind.runner, 'Build'),
  installEngine(CheckKind.engine, 'Install'),
  enableCustomDevices(CheckKind.customDevices, 'Enable'),
  register(CheckKind.device, 'Register'),

  /// [register], offered when another runner's helper is registered.
  useThisRunner(CheckKind.device, 'Use this runner');

  const FixKind(this.check, this.label);

  /// The check this fix is for.
  final CheckKind check;

  final String label;
}

/// The result of one check, with the fixes to offer when there are any.
final class RuntimeCheck {
  const RuntimeCheck({
    required this.kind,
    required this.status,
    required this.detail,
    this.fixes = const [],
  });

  final CheckKind kind;
  final CheckStatus status;

  /// What was found, or what is missing.
  final String detail;

  /// The buttons that fix it, in the order setup tries them; empty when
  /// there is nothing to press.
  final List<FixKind> fixes;

  bool get passes => status != CheckStatus.missing;
}
