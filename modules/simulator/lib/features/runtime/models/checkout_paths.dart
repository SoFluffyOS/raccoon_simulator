import 'package:path/path.dart' as p;

/// The parts of this repository the simulator runs: the runner submodule,
/// its binary and the custom device helper.
final class CheckoutPaths {
  const CheckoutPaths(this.root, {this.isWindows = false});

  /// The repository root, which holds `native/raccoon_runner`.
  final String root;

  final bool isWindows;

  String get runnerDirectory => p.join(root, 'native', 'raccoon_runner');

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

  String tool(String name) => p.join(runnerDirectory, 'tool', name);
}
