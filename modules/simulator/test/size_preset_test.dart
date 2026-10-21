import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/viewer/viewer.dart';

void main() {
  test('offers fit, a phone, a tablet and a desktop', () {
    expect(SizePreset.all.map((preset) => preset.name), [
      'Fit',
      'Phone',
      'Tablet',
      'Desktop',
    ]);
    expect(SizePreset.fit.fillsViewport, isTrue);
    expect(SizePreset.fit.pixelRatio, isNull);
    expect(SizePreset.phone.size, const Size(390, 844));
    expect(SizePreset.phone.pixelRatio, 3);
  });

  test('labels say size and pixel ratio', () {
    expect(SizePreset.fit.toString(), 'Fit');
    expect(SizePreset.phone.toString(), 'Phone 390×844 @3x');
    expect(SizePreset.tablet.toString(), 'Tablet 820×1180 @2x');
    expect(SizePreset.desktop.toString(), 'Desktop 1280×800 @1x');
  });

  test('fit fills the viewport at full scale', () {
    final layout = SizePreset.fit.layoutIn(const Size(1000, 700));
    expect(layout.logical, const Size(1000, 700));
    expect(layout.scale, 1);
  });

  test('a preset that fits is drawn at full scale', () {
    final layout = SizePreset.phone.layoutIn(const Size(1000, 900));
    expect(layout.logical, const Size(390, 844));
    expect(layout.scale, 1);
  });

  test('a preset larger than the viewport is scaled down, not cropped', () {
    final layout = SizePreset.desktop.layoutIn(const Size(640, 800));
    expect(layout.logical, const Size(1280, 800));
    expect(layout.scale, 0.5);

    final tall = SizePreset.tablet.layoutIn(const Size(1000, 590));
    expect(tall.scale, 0.5);
  });

  test('the viewer keeps the selected preset', () {
    final viewer = ViewerViewModel();
    var notified = 0;
    viewer.addListener(() => notified++);

    viewer.select(SizePreset.tablet);
    viewer.select(SizePreset.tablet);

    expect(viewer.preset, SizePreset.tablet);
    expect(notified, 1);
  });
}
