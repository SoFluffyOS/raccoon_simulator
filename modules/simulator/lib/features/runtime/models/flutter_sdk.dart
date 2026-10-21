import 'package:path/path.dart' as p;

/// A Flutter SDK on this machine.
final class FlutterSdk {
  const FlutterSdk({required this.root, this.revision, this.isWindows = false});

  final String root;

  /// The engine revision from the SDK's stamp, which picks the runtime.
  final String? revision;

  final bool isWindows;

  String get bin => p.join(root, 'bin');

  String get flutter => p.join(bin, switch (isWindows) {
    true => 'flutter.bat',
    false => 'flutter',
  });
}
