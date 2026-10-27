import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/runner_paths.dart';

/// Where runs find a downloaded runner: raccoon_runtime's [PrebuiltRunner]
/// in the simulator's runtime directory.
extension PrebuiltRunnerPaths on PrebuiltRunner {
  RunnerPaths get paths => RunnerPaths(
    directory: directory,
    binary: binary,
    deviceHelper: deviceHelper,
  );
}
