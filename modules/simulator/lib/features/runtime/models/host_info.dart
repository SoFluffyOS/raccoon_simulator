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
    environment: withToolPaths(
      Platform.operatingSystem,
      Platform.environment,
    ),
    temporaryDirectory: Directory.systemTemp.path,
    workingDirectory: Directory.current.path,
    executable: Platform.resolvedExecutable,
  );

  /// Folders an app opened from the Finder or the Dock misses: it gets
  /// launchd's bare PATH, without Homebrew's `flutter`, `cmake` and `ninja`.
  static const macosToolDirectories = ['/opt/homebrew/bin', '/usr/local/bin'];

  /// [environment] with [macosToolDirectories] at the end of its PATH on
  /// macOS, so a terminal's PATH still wins.
  static Map<String, String> withToolPaths(
    String operatingSystem,
    Map<String, String> environment,
  ) {
    if (operatingSystem != 'macos') return environment;
    final path = environment['PATH'] ?? '';
    final present = path.split(':').toSet();
    final missing = [
      for (final directory in macosToolDirectories)
        if (!present.contains(directory)) directory,
    ];
    if (missing.isEmpty) return environment;
    return {
      ...environment,
      'PATH': [if (path.isNotEmpty) path, ...missing].join(':'),
    };
  }

  final String operatingSystem;
  final Map<String, String> environment;
  final String temporaryDirectory;
  final String workingDirectory;

  /// This app's own executable.
  final String executable;

  bool get isWindows => operatingSystem == 'windows';

  String get home => environment['HOME'] ?? environment['USERPROFILE'] ?? '';
}
