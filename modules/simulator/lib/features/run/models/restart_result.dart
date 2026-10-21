import 'package:simulator/features/run/models/restart_kind.dart';

/// How the last reload or restart went.
final class RestartResult {
  const RestartResult({
    required this.kind,
    required this.duration,
    this.failure,
  });

  final RestartKind kind;
  final Duration duration;

  /// Why it failed, or null when it worked.
  final String? failure;

  bool get succeeded => failure == null;
}
