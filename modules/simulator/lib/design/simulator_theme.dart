import 'package:flutter/widgets.dart';
import 'package:simulator/design/palette.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The sofluffy_ui theme of the simulator window.
abstract final class SimulatorTheme {
  static FluffyThemeData get data => FluffyThemeData(
    colors: Palette.colors,
    typography: TypographyData.fallback(),
    brightness: Brightness.dark,
  );
}
