import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:simulator/features/board/models/models.dart';
import 'package:simulator/services/settings_store.dart';

/// Where every device sits on the board and how big it is, kept per
/// project between launches.
final class BoardViewModel extends ChangeNotifier {
  BoardViewModel({required SettingsStore settings}) : _settings = settings;

  final SettingsStore _settings;
  final _frames = <String, BoardFrame>{};
  String? _project;

  List<BoardFrame> get frames => List.unmodifiable(_frames.values);

  /// The frame for a session, made on first sight next to the others. Safe
  /// during a build: it tells nobody.
  BoardFrame frameFor(String name) {
    final existing = _frames[name];
    if (existing != null) return existing;
    final frame = BoardFrame.initial(name, existing: _frames.values);
    _frames[name] = frame;
    _save();
    return frame;
  }

  void move(String name, Offset position) {
    final frame = _frames[name];
    if (frame == null) return;
    _frames[name] = frame.copyWith(position: position);
    notifyListeners();
    _save();
  }

  /// Resizes the frame; no side goes under [BoardFrame.minSide].
  void resize(String name, Size size) {
    final frame = _frames[name];
    if (frame == null) return;
    final clamped = Size(
      size.width < BoardFrame.minSide ? BoardFrame.minSide : size.width,
      size.height < BoardFrame.minSide ? BoardFrame.minSide : size.height,
    );
    _frames[name] = frame.copyWith(size: clamped);
    notifyListeners();
    _save();
  }

  /// Takes the layout saved for a project; null forgets it.
  Future<void> load(String? projectDirectory) async {
    _project = projectDirectory;
    _frames.clear();
    if (projectDirectory != null) {
      final saved = await _settings.boardLayout(projectDirectory);
      if (saved != null) {
        try {
          for (final item in jsonDecode(saved) as List) {
            final frame = BoardFrame.fromJson(item as Map<String, Object?>);
            _frames[frame.name] = frame;
          }
        } on Object {
          _frames.clear(); // a layout that does not read is no layout
        }
      }
    }
    notifyListeners();
  }

  void _save() {
    final project = _project;
    if (project == null) return;
    unawaited(
      _settings.setBoardLayout(
        project,
        jsonEncode([for (final frame in _frames.values) frame.toJson()]),
      ),
    );
  }
}
