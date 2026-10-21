import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';

/// Where the runners this simulator starts put their sockets.
///
/// Shared: the host's usual directory, where any other client looks
/// too. Private: a directory of the simulator's own, reached by pointing
/// the device helper's base directory (`XDG_RUNTIME_DIR` on Linux, `TMPDIR`
/// on macOS) somewhere else for the `flutter run` it starts. A runner takes
/// one client at a time, so private sockets keep other clients from taking
/// the simulator's runner first.
final class RunnerSockets {
  const RunnerSockets._({
    required this.discovery,
    required this.environment,
    required this.isPrivate,
  });

  factory RunnerSockets.forHost({
    required String operatingSystem,
    required Map<String, String> environment,
    required String temporaryDirectory,
    required bool private,
  }) {
    if (!private) {
      return RunnerSockets._(
        discovery: RunnerDiscovery.forHost(
          operatingSystem: operatingSystem,
          environment: environment,
          temporaryDirectory: temporaryDirectory,
        ),
        environment: const {},
        isPrivate: false,
      );
    }
    final base = switch (environment['XDG_RUNTIME_DIR']) {
      final dir? when dir.isNotEmpty && operatingSystem == 'linux' => dir,
      _ => temporaryDirectory,
    };
    final root = p.join(base, privateFolder);
    final overrides = switch (operatingSystem) {
      'linux' => {'XDG_RUNTIME_DIR': root},
      _ => {'TMPDIR': root},
    };
    return RunnerSockets._(
      discovery: RunnerDiscovery.forHost(
        operatingSystem: operatingSystem,
        environment: {...environment, ...overrides},
        temporaryDirectory: root,
      ),
      environment: overrides,
      isPrivate: true,
    );
  }

  static const privateFolder = 'raccoon_simulator';

  final RunnerDiscovery discovery;

  /// Variables to set for `flutter run` so its runner listens in
  /// [directory].
  final Map<String, String> environment;

  final bool isPrivate;

  String get directory => discovery.directory;
}
