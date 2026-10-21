import 'package:flutter/foundation.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Whether the toolbar is the window's title bar, and how much room it leaves
/// for the window buttons.
///
/// On macOS the title bar is transparent and the content runs under it, the
/// way Lumide does it: the traffic lights sit in the toolbar's left end,
/// except in full screen, where macOS hides them.
final class WindowChrome extends ChangeNotifier {
  WindowChrome({required this.toolbarIsTitleBar});

  /// True on macOS, see `MacWindow.setUp`.
  final bool toolbarIsTitleBar;

  var _fullScreen = false;

  bool get fullScreen => _fullScreen;

  /// Room on the toolbar's left for the window buttons.
  double get leadingInset => switch (toolbarIsTitleBar && !_fullScreen) {
    true => Spacing.d68,
    false => 0,
  };

  void setFullScreen(bool value) {
    if (value == _fullScreen) return;
    _fullScreen = value;
    notifyListeners();
  }
}
