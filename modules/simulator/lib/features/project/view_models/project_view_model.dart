import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:simulator/features/project/models/models.dart';
import 'package:simulator/features/project/services/services.dart';
import 'package:simulator/services/services.dart';

/// Shows a folder picker; [getDirectoryPath] in the app.
typedef DirectoryPicker = Future<String?> Function();

/// Shows a picker for what the camera shows; [openPicture] in the app.
typedef PicturePicker = Future<String?> Function();

/// [openFile] for a PNG or JPEG, or on Windows a video too, where the runner
/// plays one; its path.
Future<String?> openPicture() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Pictures', extensions: ['png', 'jpg', 'jpeg']),
      if (Platform.isWindows)
        const XTypeGroup(
          label: 'Videos',
          extensions: ['mp4', 'mov', 'm4v', 'wmv', 'avi'],
        ),
    ],
  );
  return file?.path;
}

/// The chosen project and the recently opened ones, and the picture the
/// project's camera shows.
final class ProjectViewModel extends ChangeNotifier {
  ProjectViewModel({
    required SettingsStore settings,
    DirectoryPicker? pickDirectory,
    PicturePicker? pickPicture,
    this.maxRecent = 8,
  }) : _settings = settings,
       _pickDirectory = pickDirectory ?? getDirectoryPath,
       _pickPicture = pickPicture ?? openPicture;

  final SettingsStore _settings;
  final DirectoryPicker _pickDirectory;
  final PicturePicker _pickPicture;
  final int maxRecent;

  SimulatorProject? _project;
  List<String> _recent = const [];
  String? _error;
  String? _cameraSource;
  var _disposed = false;

  SimulatorProject? get project => _project;

  /// Recently opened folders, newest first. The same list until it changes.
  List<String> get recent => _recent;

  /// Why the last folder could not be opened.
  String? get error => _error;

  /// The picture or video the project's camera shows, or null for the
  /// runner's test pattern. Kept per project; a run picks it up when it starts.
  String? get cameraSource => _cameraSource;

  /// What a run of the project adds to the tool's environment: the camera's
  /// picture, which the runner reads.
  Map<String, String> get runEnvironment => {
    'RACCOON_CAMERA_SOURCE': ?_cameraSource,
  };

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
    _cameraSource = await _settings.cameraSource(project.directory);
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

  /// Asks for a picture or video for the project's camera and keeps it.
  Future<void> pickCameraSource() async {
    if (_project == null) return;
    final path = await _pickPicture();
    if (path == null) return;
    await _setCameraSource(path);
  }

  /// Back to the runner's test pattern.
  Future<void> clearCameraSource() => _setCameraSource(null);

  Future<void> _setCameraSource(String? path) async {
    final project = _project;
    if (project == null) return;
    _cameraSource = path;
    _notify();
    await _settings.setCameraSource(project.directory, path);
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
