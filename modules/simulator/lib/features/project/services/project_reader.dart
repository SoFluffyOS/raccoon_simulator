import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simulator/features/project/models/models.dart';
import 'package:yaml/yaml.dart';

/// Why a folder cannot be run.
final class ProjectError implements Exception {
  const ProjectError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads a folder's pubspec to tell whether it is a Flutter app.
abstract final class ProjectReader {
  static SimulatorProject read(String directory) {
    final pubspec = File(p.join(directory, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw ProjectError('No pubspec.yaml in $directory');
    }
    final Object? yaml;
    try {
      yaml = loadYaml(pubspec.readAsStringSync());
    } on YamlException catch (error) {
      throw ProjectError('pubspec.yaml does not parse: ${error.message}');
    } on FileSystemException catch (error) {
      throw ProjectError('pubspec.yaml can\'t be read: ${error.message}');
    }
    final name = switch (yaml) {
      {'name': final String name} when name.isNotEmpty => name,
      _ => throw ProjectError('pubspec.yaml in $directory has no name'),
    };
    final usesFlutter = switch (yaml) {
      {'dependencies': {'flutter': {'sdk': 'flutter'}}} => true,
      _ => false,
    };
    if (!usesFlutter) {
      throw ProjectError('$name does not depend on the Flutter SDK');
    }
    return SimulatorProject(directory: p.normalize(directory), appName: name);
  }
}
