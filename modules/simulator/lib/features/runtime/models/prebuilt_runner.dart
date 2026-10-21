import 'package:path/path.dart' as p;
import 'package:simulator/features/runtime/models/runner_paths.dart';

/// The simulator's runtime directory, where a downloaded release of the
/// runner unpacks: the binary beside `VERSION`, with `tool/raccoon-device`
/// and `tool/engine_dir.sh`, the way the runner's `tool/package.sh` packs
/// it.
final class PrebuiltRunner {
  const PrebuiltRunner(this.directory, {this.isWindows = false});

  final String directory;

  final bool isWindows;

  String get binary => p.join(directory, switch (isWindows) {
    true => 'raccoon_runner.exe',
    false => 'raccoon_runner',
  });

  String get deviceHelper => p.join(directory, 'tool', 'raccoon-device');

  /// The version that was downloaded.
  String get versionFile => p.join(directory, 'VERSION');

  RunnerPaths get paths => RunnerPaths(
    directory: directory,
    binary: binary,
    deviceHelper: deviceHelper,
  );
}
