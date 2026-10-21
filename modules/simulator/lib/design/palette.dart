import 'package:flutter/widgets.dart';

/// The simulator's colours: one dark theme, like a device frame.
abstract final class Palette {
  static const background = Color(0xFF16181D);
  static const surface = Color(0xFF1E2128);
  static const surfaceRaised = Color(0xFF272B34);
  static const viewport = Color(0xFF0E0F12);
  static const border = Color(0xFF2F3440);
  static const text = Color(0xFFE6E8EE);
  static const textMuted = Color(0xFF9AA1B0);
  static const textFaint = Color(0xFF6B7280);
  static const accent = Color(0xFF6CA8FF);
  static const hover = Color(0x14FFFFFF);
  static const pressed = Color(0x22FFFFFF);
  static const ok = Color(0xFF4CC38A);
  static const warning = Color(0xFFE5B454);
  static const error = Color(0xFFF07178);
}
