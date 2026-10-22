import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/fake_connection.dart';

void main() {
  late BoardViewModel board;

  setUp(() {
    board = BoardViewModel(settings: MemorySettingsStore());
  });

  tearDown(() => board.dispose());

  Future<Map<String, FakeConnection>> pumpBoard(
    WidgetTester tester,
    List<String> names, {
    Map<String, VoidCallback> onClose = const {},
  }) async {
    tester.view
      ..physicalSize = const Size(2400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final connections = {for (final name in names) name: FakeConnection()};
    await tester.pumpWidget(
      FluffyTheme(
        data: FluffyThemeData.fallback(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: BoardView(
            sessions: [
              for (final name in names)
                BoardSession(
                  name: name,
                  connection: connections[name]!,
                  onClose: onClose[name],
                ),
            ],
            viewModel: board,
          ),
        ),
      ),
    );
    return connections;
  }

  testWidgets('says what to do while nothing runs', (tester) async {
    await pumpBoard(tester, []);
    expect(find.textContaining('Run the project'), findsOneWidget);
    expect(find.byType(RaccoonView), findsNothing);
  });

  testWidgets('each session gets a frame at its device size', (tester) async {
    final connections = await pumpBoard(tester, ['counter', 'wonders@tablet']);
    expect(find.byType(RaccoonView), findsNWidgets(2));
    expect(connections['counter']!.resizes.last, (
      width: 780,
      height: 1688,
      pixelRatio: 2.0,
    ));
    expect(connections['wonders@tablet']!.resizes.last, (
      width: 1640,
      height: 2360,
      pixelRatio: 2.0,
    ));
    expect(find.text('Raccoon · counter · 390 × 844 · 2x'), findsOneWidget);
    expect(
      find.text('Raccoon Tablet · wonders · 820 × 1180 · 2x'),
      findsOneWidget,
    );
    final first = tester.getTopLeft(find.byType(RaccoonView).first);
    final second = tester.getTopLeft(find.byType(RaccoonView).last);
    expect(second.dx, first.dx + 390 + BoardFrame.gap);
    expect(second.dy, first.dy);
  });

  testWidgets('dragging the title moves the frame', (tester) async {
    await pumpBoard(tester, ['counter']);
    final before = board.frameFor('counter').position;
    await tester.drag(
      find.byKey(BoardView.titleKey('counter')),
      const Offset(120, 80),
    );
    await tester.pump();
    expect(board.frameFor('counter').position, before + const Offset(120, 80));
    expect(
      tester.getTopLeft(find.byType(RaccoonView)),
      before + const Offset(120, 80),
    );
  });

  testWidgets('the corner handle resizes the frame and the app', (
    tester,
  ) async {
    final connections = await pumpBoard(tester, ['counter']);
    await tester.drag(
      find.byKey(BoardView.resizeKey('counter')),
      const Offset(50, -44),
    );
    await tester.pump();
    expect(board.frameFor('counter').size, const Size(440, 800));
    expect(connections['counter']!.resizes.last, (
      width: 880,
      height: 1600,
      pixelRatio: 2.0,
    ));
  });

  testWidgets('holding Alt makes the whole frame a handle', (tester) async {
    final connections = await pumpBoard(tester, ['counter']);
    expect(find.byKey(BoardView.grabKey('counter')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(find.byKey(BoardView.grabKey('counter')), findsOneWidget);

    final before = board.frameFor('counter').position;
    final pointers = connections['counter']!.pointers.length;
    await tester.drag(
      find.byKey(BoardView.grabKey('counter')),
      const Offset(-30, 40),
    );
    await tester.pump();
    expect(board.frameFor('counter').position, before + const Offset(-30, 40));
    expect(connections['counter']!.pointers.length, pointers);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(find.byKey(BoardView.grabKey('counter')), findsNothing);
  });

  testWidgets('close asks the session to go', (tester) async {
    var closed = 0;
    await pumpBoard(tester, ['counter'], onClose: {'counter': () => closed++});
    await tester.tap(find.byKey(BoardView.closeKey('counter')));
    expect(closed, 1);
  });

  testWidgets('zoomed out, a frame still follows the pointer', (tester) async {
    await pumpBoard(tester, ['counter']);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(const Offset(10, 10));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final shown = tester.getRect(find.byType(RaccoonView));
    expect(shown.width, lessThan(390 * 0.7));

    await tester.drag(
      find.byKey(BoardView.titleKey('counter')),
      const Offset(100, 50),
    );
    await tester.pump();
    final moved = tester.getTopLeft(find.byType(RaccoonView));
    expect(moved.dx, closeTo(shown.left + 100, 0.5));
    expect(moved.dy, closeTo(shown.top + 50, 0.5));

    await tester.drag(
      find.byKey(BoardView.resizeKey('counter')),
      const Offset(60, 30),
    );
    await tester.pump();
    final grown = tester.getRect(find.byType(RaccoonView));
    expect(grown.width, closeTo(shown.width + 60, 0.5));
    expect(grown.height, closeTo(shown.height + 30, 0.5));
  });

  testWidgets('scrolling pans the board', (tester) async {
    await pumpBoard(tester, ['counter']);
    final before = tester.getTopLeft(find.byType(RaccoonView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(const Offset(1000, 1000));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(RaccoonView)),
      before - const Offset(0, 100),
    );
  });
}
