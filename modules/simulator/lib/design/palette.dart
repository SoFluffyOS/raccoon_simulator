import 'package:flutter/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The simulator's colours: one dark theme, like a device frame. The
/// neutrals run from text (1) to the window's background (7), the way
/// sofluffy_ui reads them in dark mode.
abstract final class Palette {
  static const accent = Color(0xFF6CA8FF);
  static const text = Color(0xFFE6E8EE);
  static const textMuted = Color(0xFF9AA1B0);
  static const textFaint = Color(0xFF6B7280);
  static const border = Color(0xFF2F3440);
  static const surface = Color(0xFF1E2128);
  static const background = Color(0xFF16181D);

  /// Behind the hosted app.
  static const viewport = Color(0xFF0E0F12);

  static const ok = FluffyColors.success;
  static const warning = FluffyColors.warning;
  static const error = FluffyColors.error;

  static const colors = ColorData(
    primary: accent,
    secondary: accent,
    neutral1: text,
    neutral2: Color(0xFFC4C8D2),
    neutral3: textMuted,
    neutral4: textFaint,
    neutral5: border,
    neutral6: surface,
    neutral7: background,
  );
}
