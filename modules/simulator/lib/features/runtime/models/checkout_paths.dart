import 'package:path/path.dart' as p;
import 'package:simulator/features/runtime/models/runner_paths.dart';

/// The parts of this repository the simulator runs: the runner submodule,
/// its binary and the custom device helper.
final class CheckoutPaths {
  const CheckoutPaths(this.root, {this.isWindows = false});

  /// The repository root, which holds `raccoon/native/raccoon_runner`.
  final String root;

  final bool isWindows;

  String get runnerDirectory =>
      p.join(root, 'raccoon', 'native', 'raccoon_runner');

  String get runnerBinary => p.join(
    runnerDirectory,
    'build',
    switch (isWindows) {
      true => 'raccoon_runner.exe',
      false => 'raccoon_runner',
    },
  );

  /// The script the tool's `custom_devices.json` entry points at.
  String get deviceHelper => p.join(runnerDirectory, 'tool', 'raccoon-device');

  /// The runner version this checkout pins, which a downloaded runner must
  /// be compatible with.
  String get runnerVersionFile => p.join(runnerDirectory, 'VERSION');

  RunnerPaths get runner => RunnerPaths(
    directory: runnerDirectory,
    binary: runnerBinary,
    deviceHelper: deviceHelper,
  );

  String tool(String name) => p.join(runnerDirectory, 'tool', name);
}
