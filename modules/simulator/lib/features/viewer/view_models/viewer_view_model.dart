import 'package:flutter/foundation.dart';
import 'package:simulator/features/viewer/models/models.dart';

/// The size preset the viewport shows the app at.
final class ViewerViewModel extends ChangeNotifier {
  ViewerViewModel({SizePreset preset = SizePreset.fit}) : _preset = preset;

  SizePreset _preset;

  SizePreset get preset => _preset;

  void select(SizePreset preset) {
    if (preset == _preset) return;
    _preset = preset;
    notifyListeners();
  }
}
