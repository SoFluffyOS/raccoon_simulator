import 'package:path/path.dart' as p;

/// A Flutter project the simulator can run.
final class SimulatorProject {
  const SimulatorProject({required this.directory, required this.appName});

  final String directory;

  /// The pubspec's `name`: the tool names the app, and so the runner's
  /// socket, after it.
  final String appName;

  String get folderName => p.basename(directory);
}
