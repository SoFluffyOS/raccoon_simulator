import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/features.dart';

void main() {
  test('a sized device gets its size and ratio', () {
    final frame = BoardFrame.initial('wonders@tablet');
    expect(frame.size, const Size(820, 1180));
    expect(frame.pixelRatio, 2);
    expect(frame.device, 'Raccoon Tablet');
    expect(frame.project, 'wonders');
    expect(frame.label, '820 × 1180 · 2x');
  });

  test('a plain name gets a phone-sized frame', () {
    final frame = BoardFrame.initial('counter');
    expect(frame.size, const Size(390, 844));
    expect(frame.pixelRatio, 2);
    expect(frame.device, 'Raccoon');
    expect(frame.position, const Offset(BoardFrame.gap, BoardFrame.gap));
  });

  test('a new frame goes right of the ones there', () {
    final first = BoardFrame.initial('a');
    final second = BoardFrame.initial('b@desktop', existing: [first]);
    expect(second.position.dx, first.position.dx + 390 + BoardFrame.gap);
    expect(second.position.dy, BoardFrame.gap);
    final third = BoardFrame.initial('c', existing: [first, second]);
    expect(third.position.dx, second.position.dx + 1280 + BoardFrame.gap);
  });

  test('round-trips through json', () {
    final frame = BoardFrame.initial(
      'wonders@2',
    ).copyWith(position: const Offset(10, 20), size: const Size(300, 400));
    final back = BoardFrame.fromJson(frame.toJson());
    expect(back.name, 'wonders@2');
    expect(back.position, const Offset(10, 20));
    expect(back.size, const Size(300, 400));
    expect(back.pixelRatio, 2);
    expect(back.device, 'Raccoon 2');
  });
}
