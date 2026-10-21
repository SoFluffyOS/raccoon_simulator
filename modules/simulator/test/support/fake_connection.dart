import 'dart:async';

import 'package:raccoon/raccoon.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';

/// A [RunnerConnection] that records what the view sends.
final class FakeConnection implements RunnerConnection {
  final _frames = StreamController<Frame>.broadcast();
  final resizes = <({int width, int height, double pixelRatio})>[];
  final pointers = <PointerEvent>[];

  @override
  Stream<Frame> get frames => _frames.stream;

  @override
  void resize(int width, int height, double pixelRatio) =>
      resizes.add((width: width, height: height, pixelRatio: pixelRatio));

  @override
  void sendPointer(PointerEvent event) => pointers.add(event);

  @override
  void sendKey(KeyEvent event) {}
}
