import 'dart:math' as math;
import 'dart:ui';

import 'package:raccoon_runtime/raccoon_runtime.dart';

/// One device on the board: where its frame sits, how big it is in logical
/// pixels, and at what pixel ratio the app draws.
final class BoardFrame {
  const BoardFrame({
    required this.name,
    required this.position,
    required this.size,
    required this.pixelRatio,
  });

  /// A frame for a session's name: the device's size and ratio when the
  /// name carries a sized device (`wonders@tablet`), the phone's otherwise,
  /// placed to the right of [existing].
  factory BoardFrame.initial(
    String name, {
    Iterable<BoardFrame> existing = const [],
  }) {
    final device = RaccoonDevice.forKey(RunnerDiscovery.instanceOf(name));
    final width = device?.width;
    final height = device?.height;
    final size = width != null && height != null
        ? Size(width.toDouble(), height.toDouble())
        : const Size(390, 844);
    var x = gap;
    for (final frame in existing) {
      x = math.max(x, frame.position.dx + frame.size.width + gap);
    }
    return BoardFrame(
      name: name,
      position: Offset(x, gap),
      size: size,
      pixelRatio: device?.pixelRatio ?? 2,
    );
  }

  factory BoardFrame.fromJson(Map<String, Object?> json) => BoardFrame(
    name: json['name'] as String,
    position: Offset(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    ),
    size: Size(
      (json['width'] as num).toDouble(),
      (json['height'] as num).toDouble(),
    ),
    pixelRatio: (json['pixelRatio'] as num).toDouble(),
  );

  /// Space between frames, and from the board's edge, when placed.
  static const gap = 48.0;

  /// No side goes under this when resized.
  static const minSide = 160.0;

  final String name;
  final Offset position;
  final Size size;
  final double pixelRatio;

  /// The device's label: `Raccoon Tablet`, `Raccoon 2`, `Raccoon`.
  String get device {
    final key = RunnerDiscovery.instanceOf(name);
    return RaccoonDevice.forKey(key)?.label ?? 'Raccoon $key';
  }

  String get project => RunnerDiscovery.projectOf(name);

  /// `820 × 1180 · 2x`.
  String get label {
    final ratio = pixelRatio == pixelRatio.roundToDouble()
        ? '${pixelRatio.round()}'
        : '$pixelRatio';
    return '${size.width.round()} × ${size.height.round()} · ${ratio}x';
  }

  BoardFrame copyWith({Offset? position, Size? size}) => BoardFrame(
    name: name,
    position: position ?? this.position,
    size: size ?? this.size,
    pixelRatio: pixelRatio,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'width': size.width,
    'height': size.height,
    'pixelRatio': pixelRatio,
  };
}
