import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:simulator/features/run/models/models.dart';

/// The lines of the log panel, oldest first, capped at [capacity]. Bursts of
/// lines notify once.
final class RunLog extends ChangeNotifier {
  RunLog({this.capacity = 5000});

  final int capacity;
  final _lines = <LogLine>[];
  var _revision = 0;
  var _notifyScheduled = false;
  var _disposed = false;

  List<LogLine> get lines => List.unmodifiable(_lines);

  int get length => _lines.length;

  LogLine lineAt(int index) => _lines[index];

  /// Changes whenever the lines do, for `context.select`.
  int get revision => _revision;

  void add(LogSource source, String text) {
    _lines.add(LogLine(source, text));
    final overflow = _lines.length - capacity;
    if (overflow > 0) _lines.removeRange(0, overflow);
    _changed();
  }

  void clear() {
    _lines.clear();
    _changed();
  }

  /// The whole log as text, for the clipboard.
  String get text => _lines.map((line) => line.text).join('\n');

  void _changed() {
    _revision++;
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
