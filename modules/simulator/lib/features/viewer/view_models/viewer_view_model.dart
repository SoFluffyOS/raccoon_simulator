import 'package:flutter/foundation.dart';
import 'package:simulator/features/viewer/models/models.dart';

/// The size preset the viewport shows the app at, and whether it is the
/// board instead: every running device on one canvas.
final class ViewerViewModel extends ChangeNotifier {
  ViewerViewModel({SizePreset preset = SizePreset.fit, bool boardOn = false})
    : _preset = preset,
      _boardOn = boardOn;

  SizePreset _preset;
  bool _boardOn;

  SizePreset get preset => _preset;

  bool get boardOn => _boardOn;

  void toggleBoard() {
    _boardOn = !_boardOn;
    notifyListeners();
  }

  void select(SizePreset preset) {
    if (preset == _preset) return;
    _preset = preset;
    notifyListeners();
  }
}
