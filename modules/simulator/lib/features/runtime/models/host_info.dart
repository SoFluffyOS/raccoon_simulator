import 'dart:io';

/// The facts about this machine the simulator decides from, gathered once so
/// tests can pass their own.
final class HostInfo {
  const HostInfo({
    required this.operatingSystem,
    required this.environment,
    required this.temporaryDirectory,
    required this.workingDirectory,
    required this.executable,
  });

  factory HostInfo.current() => HostInfo(
    operatingSystem: Platform.operatingSystem,
    environment: Platform.environment,
    temporaryDirectory: Directory.systemTemp.path,
    workingDirectory: Directory.current.path,
    executable: Platform.resolvedExecutable,
  );

  final String operatingSystem;
  final Map<String, String> environment;
  final String temporaryDirectory;
  final String workingDirectory;

  /// This app's own executable.
  final String executable;

  bool get isWindows => operatingSystem == 'windows';

  String get home => environment['HOME'] ?? environment['USERPROFILE'] ?? '';
}
