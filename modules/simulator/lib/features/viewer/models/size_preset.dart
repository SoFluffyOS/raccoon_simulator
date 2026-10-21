import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A size to show the app at: the viewport's own size, or a device's logical
/// size and pixel ratio, scaled down to fit when the viewport is smaller.
final class SizePreset {
  const SizePreset._(this.name, {this.size, this.pixelRatio});

  /// Fills the viewport at the display's pixel ratio.
  static const fit = SizePreset._('Fit');

  static const phone = SizePreset._(
    'Phone',
    size: Size(390, 844),
    pixelRatio: 3,
  );

  static const tablet = SizePreset._(
    'Tablet',
    size: Size(820, 1180),
    pixelRatio: 2,
  );

  static const desktop = SizePreset._(
    'Desktop',
    size: Size(1280, 800),
    pixelRatio: 1,
  );

  static const all = [fit, phone, tablet, desktop];

  /// The preset after this one in [all], wrapping around; for the single
  /// preset button of a narrow window.
  SizePreset get next => all[(all.indexOf(this) + 1) % all.length];

  final String name;

  /// Logical size, or null to fill the viewport.
  final Size? size;

  /// Device pixel ratio, or null for the display's.
  final double? pixelRatio;

  bool get fillsViewport => size == null;

  /// The app's logical size in a viewport of [available], and the scale it
  /// is drawn at: never above 1, so a preset is shrunk, not blown up.
  ({Size logical, double scale}) layoutIn(Size available) {
    final size = this.size;
    if (size == null) return (logical: available, scale: 1);
    final scale = math.min(
      1.0,
      math.min(available.width / size.width, available.height / size.height),
    );
    return (logical: size, scale: math.max(0, scale));
  }

  @override
  String toString() => switch ((size, pixelRatio)) {
    (final size?, final ratio?) =>
      '$name ${size.width.round()}×${size.height.round()} @${_label(ratio)}x',
    _ => name,
  };

  static String _label(double ratio) =>
      switch (ratio == ratio.roundToDouble()) {
        true => '${ratio.round()}',
        false => '$ratio',
      };
}
