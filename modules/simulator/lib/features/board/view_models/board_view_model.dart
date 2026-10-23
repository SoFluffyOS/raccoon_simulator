import 'dart:async';

import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/services/settings_store.dart';

/// The board's layout, kept per project in the settings between launches;
/// each app's size also goes to [sizes], for its next run to start at.
final class BoardViewModel extends RaccoonBoardLayout {
  BoardViewModel({required SettingsStore settings, super.sizes})
    : _settings = settings;

  final SettingsStore _settings;
  String? _project;

  /// Takes the layout saved for a project; null forgets it.
  Future<void> load(String? projectDirectory) async {
    _project = projectDirectory;
    var frames = const <RaccoonBoardFrame>[];
    if (projectDirectory != null) {
      final saved = await _settings.boardLayout(projectDirectory);
      if (saved != null) frames = RaccoonBoardLayout.parse(saved);
    }
    replaceAll(frames);
  }

  @override
  void didChange() {
    final project = _project;
    if (project == null) return;
    unawaited(_settings.setBoardLayout(project, toJson()));
  }
}
