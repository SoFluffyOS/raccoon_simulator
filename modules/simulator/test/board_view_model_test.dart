import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';

void main() {
  late MemorySettingsStore settings;
  late BoardViewModel board;

  setUp(() {
    settings = MemorySettingsStore();
    board = BoardViewModel(settings: settings);
  });

  tearDown(() => board.dispose());

  test('frames are made on first sight, next to each other', () {
    final first = board.frameFor('a');
    final second = board.frameFor('b@tablet');
    expect(board.frameFor('a'), same(first));
    expect(second.position.dx, greaterThan(first.position.dx + 390));
    expect(board.frames, [first, second]);
  });

  test('moving and resizing tell listeners and clamp the size', () {
    var told = 0;
    board.addListener(() => told++);
    board.frameFor('a');

    board.move('a', const Offset(100, 200));
    expect(board.frameFor('a').position, const Offset(100, 200));
    expect(told, 1);

    board.resize('a', const Size(10, 500));
    expect(board.frameFor('a').size, const Size(BoardFrame.minSide, 500));
    expect(told, 2);

    board.move('nobody', Offset.zero);
    board.resize('nobody', const Size(1, 1));
    expect(told, 2);
  });

  test('the layout is saved per project and comes back', () async {
    await board.load('/p/one');
    board.frameFor('a');
    board.move('a', const Offset(5, 6));
    await board.load('/p/two');
    expect(board.frames, isEmpty);
    board.frameFor('a');
    expect(board.frameFor('a').position, isNot(const Offset(5, 6)));

    await board.load('/p/one');
    expect(board.frameFor('a').position, const Offset(5, 6));

    final fresh = BoardViewModel(settings: settings);
    await fresh.load('/p/one');
    expect(fresh.frameFor('a').position, const Offset(5, 6));
    fresh.dispose();
  });

  test('nothing is saved without a project', () async {
    board.frameFor('a');
    board.move('a', const Offset(5, 6));
    expect(await settings.boardLayout('/p/one'), isNull);
  });

  test('a layout that does not read is dropped', () async {
    await settings.setBoardLayout('/p/one', 'not json');
    await board.load('/p/one');
    expect(board.frames, isEmpty);
    expect(board.frameFor('a').position, isNotNull);
  });
}
