import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

extension ScreenSizeBuildContextExt on BuildContext {
  /// The window's size class from the app's [ScreenSizeNotifier]; rebuilds
  /// only when the class changes.
  ScreenSize get screenSize =>
      select((ScreenSizeNotifier notifier) => notifier.screenSize);
}
