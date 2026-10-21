import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/features/viewer/viewer.dart';

import 'support/fake_connection.dart';

void main() {
  Future<FakeConnection> pumpViewport(
    WidgetTester tester,
    SizePreset preset, {
    Size viewport = const Size(800, 600),
  }) async {
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final connection = FakeConnection();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AppViewport(connection: connection, preset: preset),
      ),
    );
    return connection;
  }

  testWidgets('fit renders at the viewport size and display ratio', (
    tester,
  ) async {
    final connection = await pumpViewport(tester, SizePreset.fit);
    expect(connection.resizes.last, (
      width: 800,
      height: 600,
      pixelRatio: 1.0,
    ));
    expect(tester.getSize(find.byType(RaccoonView)), const Size(800, 600));
  });

  testWidgets('a phone renders at its size and pixel ratio, scaled to fit', (
    tester,
  ) async {
    final connection = await pumpViewport(tester, SizePreset.phone);
    expect(connection.resizes.last, (
      width: 1170,
      height: 2532,
      pixelRatio: 3.0,
    ));
    expect(tester.getSize(find.byType(RaccoonView)), const Size(390, 844));
    final shown = tester.getRect(find.byType(RaccoonView));
    expect(shown.height, lessThanOrEqualTo(600));
    expect(shown.width / shown.height, closeTo(390 / 844, 0.01));
  });

  testWidgets('a preset that fits is shown at full size', (tester) async {
    await pumpViewport(
      tester,
      SizePreset.desktop,
      viewport: const Size(1600, 1000),
    );
    expect(
      tester.getRect(find.byType(RaccoonView)).size,
      const Size(1280, 800),
    );
  });

  testWidgets('taps reach the runner in the preset coordinates', (
    tester,
  ) async {
    final connection = await pumpViewport(tester, SizePreset.phone);
    await tester.tapAt(tester.getCenter(find.byType(RaccoonView)));
    final down = connection.pointers.first;
    expect(down.x, closeTo(390 * 3 / 2, 3));
    expect(down.y, closeTo(844 * 3 / 2, 3));
  });
}
