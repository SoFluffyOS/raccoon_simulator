import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/runtime/models/models.dart';

/// Finds the Flutter SDK, this repository's checkout, and tools on the PATH.
abstract final class HostLocator {
  /// Set to the repository root when the app runs from somewhere else.
  static const rootVariable = 'RACCOON_SIMULATOR_ROOT';

  /// [name] on the host's PATH, or null.
  static String? findOnPath(String name, HostInfo host) {
    final separator = switch (host.isWindows) {
      true => ';',
      false => ':',
    };
    final suffixes = switch (host.isWindows) {
      true => const ['.exe', '.bat', '.cmd'],
      false => const [''],
    };
    final path = host.environment['PATH'] ?? '';
    for (final directory in path.split(separator)) {
      if (directory.isEmpty) continue;
      for (final suffix in suffixes) {
        final candidate = p.join(directory, '$name$suffix');
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return null;
  }

  /// The SDK from `FLUTTER_ROOT`, else the `flutter` on the PATH, else FVM's
  /// default version.
  static FlutterSdk? flutterSdk(HostInfo host) {
    final executable = switch (host.isWindows) {
      true => 'flutter.bat',
      false => 'flutter',
    };
    final candidates = [
      if (host.environment['FLUTTER_ROOT'] case final root?
          when root.isNotEmpty)
        p.join(root, 'bin', executable),
      ?findOnPath('flutter', host),
      if (host.home.isNotEmpty)
        p.join(host.home, 'fvm', 'default', 'bin', executable),
    ];
    for (final candidate in candidates) {
      if (!File(candidate).existsSync()) continue;
      final root = RuntimeStore.sdkRootOfFlutter(candidate);
      return FlutterSdk(
        root: root,
        revision: RuntimeStore.revisionOfSdk(root),
        isWindows: host.isWindows,
      );
    }
    return null;
  }

  /// The repository root: [rootVariable] when set, else the first directory
  /// above the working directory or this app's executable that holds the
  /// runner submodule's device helper.
  static CheckoutPaths? checkout(HostInfo host) {
    final starts = [
      if (host.environment[rootVariable] case final root? when root.isNotEmpty)
        root,
      host.workingDirectory,
      p.dirname(host.executable),
    ];
    for (final start in starts) {
      var directory = p.normalize(p.absolute(start));
      while (true) {
        final paths = CheckoutPaths(directory, isWindows: host.isWindows);
        if (File(paths.deviceHelper).existsSync()) return paths;
        final parent = p.dirname(directory);
        if (parent == directory) break;
        directory = parent;
      }
    }
    return null;
  }

  /// The tool's settings file, which holds `enable-custom-devices`.
  static String flutterSettings(HostInfo host) {
    final configHome = switch (host.environment['XDG_CONFIG_HOME']) {
      final dir? when dir.isNotEmpty => dir,
      _ => p.join(host.home, '.config'),
    };
    return p.join(configHome, 'flutter', 'settings');
  }
}
