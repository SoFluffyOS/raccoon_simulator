import 'dart:async';

import 'package:macos_window_utils/macos/ns_window_delegate.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:simulator/services/window_chrome.dart';

/// The macOS window without the default title bar, as Lumide sets it up: the
/// content runs under a transparent, untitled title bar, and a unified
/// compact toolbar keeps the traffic lights centred in the simulator's own
/// toolbar. Full screen hides them, so the toolbar is removed there.
abstract final class MacWindow {
  static Future<void> setUp(WindowChrome chrome) async {
    await WindowManipulator.initialize(enableWindowDelegate: true);
    unawaited(WindowManipulator.setWindowBackgroundColorToDefaultColor());
    unawaited(WindowManipulator.enableFullSizeContentView());
    unawaited(WindowManipulator.makeTitlebarTransparent());
    unawaited(WindowManipulator.hideTitle());
    unawaited(WindowManipulator.enableShadow());
    _showToolbar();
    WindowManipulator.addNSWindowDelegate(
      _FullScreenDelegate((fullScreen) {
        chrome.setFullScreen(fullScreen);
        if (fullScreen) {
          unawaited(WindowManipulator.removeToolbar());
          return;
        }
        _showToolbar();
      }),
    );
  }

  static void _showToolbar() {
    unawaited(WindowManipulator.addToolbar());
    unawaited(
      WindowManipulator.setToolbarStyle(
        toolbarStyle: NSWindowToolbarStyle.unifiedCompact,
      ),
    );
  }
}

/// Tells as the window starts to enter or leave full screen, so the toolbar
/// gives or takes back the window buttons' room in time.
final class _FullScreenDelegate extends NSWindowDelegate {
  _FullScreenDelegate(this._onChanged);

  final void Function(bool fullScreen) _onChanged;

  @override
  void windowWillEnterFullScreen() => _onChanged(true);

  @override
  void windowWillExitFullScreen() => _onChanged(false);
}
