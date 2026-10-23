import 'package:shared_preferences/shared_preferences.dart';

/// The few values the simulator remembers between launches.
abstract interface class SettingsStore {
  Future<List<String>> recentProjects();

  Future<void> setRecentProjects(List<String> directories);

  /// Whether runs keep their sockets private, see `RunnerSockets`; null
  /// until the user chose.
  Future<bool?> privateSockets();

  Future<void> setPrivateSockets(bool value);

  /// The board's layout for a project directory, as the board saved it;
  /// null until it did.
  Future<String?> boardLayout(String directory);

  Future<void> setBoardLayout(String directory, String json);

  /// The picture a project's camera shows, see `RACCOON_CAMERA_SOURCE`; null
  /// for the runner's test pattern.
  Future<String?> cameraSource(String directory);

  /// Sets or, with null, clears [directory]'s camera picture.
  Future<void> setCameraSource(String directory, String? path);
}

/// [SettingsStore] in the platform's shared preferences.
final class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _recentKey = 'recentProjects';
  static const _privateKey = 'privateSockets';
  static const _boardKey = 'board';
  static const _cameraKey = 'camera';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<String>> recentProjects() async =>
      await _preferences.getStringList(_recentKey) ?? const [];

  @override
  Future<void> setRecentProjects(List<String> directories) =>
      _preferences.setStringList(_recentKey, directories);

  @override
  Future<bool?> privateSockets() => _preferences.getBool(_privateKey);

  @override
  Future<void> setPrivateSockets(bool value) =>
      _preferences.setBool(_privateKey, value);

  @override
  Future<String?> boardLayout(String directory) =>
      _preferences.getString('$_boardKey:$directory');

  @override
  Future<void> setBoardLayout(String directory, String json) =>
      _preferences.setString('$_boardKey:$directory', json);

  @override
  Future<String?> cameraSource(String directory) =>
      _preferences.getString('$_cameraKey:$directory');

  @override
  Future<void> setCameraSource(String directory, String? path) =>
      switch (path) {
        final path? => _preferences.setString('$_cameraKey:$directory', path),
        null => _preferences.remove('$_cameraKey:$directory'),
      };
}

/// [SettingsStore] in memory, for tests and when preferences fail.
final class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore({List<String> recent = const [], bool? private})
    : _recent = [...recent],
      _private = private;

  List<String> _recent;
  bool? _private;
  final _boards = <String, String>{};
  final _cameras = <String, String>{};

  @override
  Future<List<String>> recentProjects() async => [..._recent];

  @override
  Future<void> setRecentProjects(List<String> directories) async =>
      _recent = [...directories];

  @override
  Future<bool?> privateSockets() async => _private;

  @override
  Future<void> setPrivateSockets(bool value) async => _private = value;

  @override
  Future<String?> boardLayout(String directory) async => _boards[directory];

  @override
  Future<void> setBoardLayout(String directory, String json) async =>
      _boards[directory] = json;

  @override
  Future<String?> cameraSource(String directory) async => _cameras[directory];

  @override
  Future<void> setCameraSource(String directory, String? path) async {
    if (path == null) {
      _cameras.remove(directory);
      return;
    }
    _cameras[directory] = path;
  }
}
