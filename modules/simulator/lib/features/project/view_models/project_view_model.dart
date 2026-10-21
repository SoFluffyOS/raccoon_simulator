import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:simulator/features/project/models/models.dart';
import 'package:simulator/features/project/services/services.dart';
import 'package:simulator/services/services.dart';

/// Shows a folder picker; [getDirectoryPath] in the app.
typedef DirectoryPicker = Future<String?> Function();

/// The chosen project and the recently opened ones.
final class ProjectViewModel extends ChangeNotifier {
  ProjectViewModel({
    required SettingsStore settings,
    DirectoryPicker? pickDirectory,
    this.maxRecent = 8,
  }) : _settings = settings,
       _pickDirectory = pickDirectory ?? getDirectoryPath;

  final SettingsStore _settings;
  final DirectoryPicker _pickDirectory;
  final int maxRecent;

  SimulatorProject? _project;
  List<String> _recent = const [];
  String? _error;
  var _disposed = false;

  SimulatorProject? get project => _project;

  /// Recently opened folders, newest first. The same list until it changes.
  List<String> get recent => _recent;

  /// Why the last folder could not be opened.
  String? get error => _error;

  Future<void> init({String? initialDirectory}) async {
    _recent = List.unmodifiable(await _settings.recentProjects());
    _notify();
    if (initialDirectory case final directory?) await open(directory);
  }

  /// Asks for a folder and opens it.
  Future<void> pick() async {
    final directory = await _pickDirectory();
    if (directory == null) return;
    await open(directory);
  }

  /// Opens [directory] when it is a Flutter project, and remembers it.
  Future<void> open(String directory) async {
    final SimulatorProject project;
    try {
      project = ProjectReader.read(directory);
    } on ProjectError catch (error) {
      _error = error.message;
      _notify();
      return;
    }
    _project = project;
    _error = null;
    _recent = List.unmodifiable(
      [
        project.directory,
        for (final known in _recent)
          if (known != project.directory) known,
      ].take(maxRecent),
    );
    _notify();
    await _settings.setRecentProjects(_recent);
  }

  Future<void> forget(String directory) async {
    _recent = List.unmodifiable([
      for (final known in _recent)
        if (known != directory) known,
    ]);
    _notify();
    await _settings.setRecentProjects(_recent);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
