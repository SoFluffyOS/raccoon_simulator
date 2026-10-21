import 'package:flutter/widgets.dart';
import 'package:simulator/design/palette.dart';
import 'package:simulator/design/spacing.dart';

/// Text styles. The log uses the system's monospace face.
abstract final class Typography {
  static const body = TextStyle(
    color: Palette.text,
    fontSize: Spacing.fontBody,
    height: 1.35,
  );

  static const caption = TextStyle(
    color: Palette.textMuted,
    fontSize: Spacing.fontCaption,
    height: 1.3,
  );

  static const title = TextStyle(
    color: Palette.text,
    fontSize: Spacing.fontTitle,
    fontWeight: FontWeight.w600,
  );

  static const section = TextStyle(
    color: Palette.textFaint,
    fontSize: Spacing.fontCaption,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const mono = TextStyle(
    color: Palette.text,
    fontSize: Spacing.fontCaption,
    fontFamily: 'monospace',
    height: 1.4,
  );
}
