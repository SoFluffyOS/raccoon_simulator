// Drives the real simulator window against the real runtime: opens a project
// (the runner's example/hello by default), runs it on Raccoon, taps its box
// through the viewport and checks the app turns it green, hot reloads, hot
// restarts (the box is red again), answers the app's clipboard read over
// the platform channel (purple), switches to the phone preset, and stops.
// The box's colour is read from the runner's frame when it carries pixels,
// else from the window, where a GPU buffer frame shows through the host's
// texture.
//
//   flutter test integration_test/hello_e2e_test.dart -d <linux or macos> \
//     [--dart-define=RACCOON_E2E_PROJECT=<folder of a hello-like app>] \
//     [--dart-define=RACCOON_E2E_SCREENSHOTS=<folder for PNGs>]
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon/raccoon.dart' as rc;
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/simulator.dart';

const _project = String.fromEnvironment('RACCOON_E2E_PROJECT');
const _screenshots = String.fromEnvironment('RACCOON_E2E_SCREENSHOTS');

const _red = (0xE5, 0x39, 0x35);
const _green = (0x43, 0xA0, 0x47);
const _purple = (0x8E, 0x24, 0xAA);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs hello on Raccoon and it reacts to a tap', (tester) async {
    final host = HostInfo.current();
    final checkout = HostLocator.checkout(host);
    expect(checkout, isNotNull, reason: 'run from the repository');
    final project = switch (_project) {
      '' => p.join(checkout?.runnerDirectory ?? '', 'example', 'hello'),
      final path => path,
    };
    final services = SimulatorServices.create(
      host: host,
      settings: MemorySettingsStore(private: true),
    );
    // A test app is killed without unmounting, so the run must be stopped
    // here or its runner outlives the test.
    addTearDown(services.controller.stop);

    await tester.pumpWidget(
      SimulatorApp(
        services: services,
        options: SimulatorOptions(project: project, run: true),
      ),
    );

    _log = services.log;
    final name = services.project.project?.appName ?? 'hello';
    rc.Frame? frame() => services.sessions.session(name)?.client.latestFrame;
    Future<(int, int, int)?> centre() => _appCentre(tester, frame());
    _lastCentre = centre;

    await _pumpUntil(
      tester,
      () => services.run.phase == RunPhase.running && frame() != null,
      'the app running with a frame',
      timeout: const Duration(minutes: 3),
    );
    await _pumpUntil(tester, () async => await centre() == _red, 'the red box');
    expect(find.byType(RaccoonView), findsOneWidget);
    _report('launch ${services.run.launchTime?.inMilliseconds} ms');
    _report('frame ${_kindOf(frame())}');
    await _screenshot(tester, '1-running');

    await tester.tap(find.byType(RaccoonView));
    await _pumpUntil(
      tester,
      () async => await centre() == _green,
      'the box to turn green after a tap',
    );
    _report('frame ${_kindOf(frame())}');
    await _screenshot(tester, '2-tapped');

    await tester.tap(find.byKey(ToolbarFrame.reloadKey));
    await _pumpUntil(
      tester,
      () => services.run.lastRestart?.kind == RestartKind.hotReload,
      'the hot reload',
    );
    expect(services.run.lastRestart?.succeeded, isTrue);
    expect(await centre(), _green, reason: 'a reload keeps state');
    _report(
      'hot reload ${services.run.lastRestart?.duration.inMilliseconds} ms',
    );

    await tester.tap(find.byKey(ToolbarFrame.restartKey));
    await _pumpUntil(
      tester,
      () => services.run.lastRestart?.kind == RestartKind.hotRestart,
      'the hot restart',
    );
    expect(services.run.lastRestart?.succeeded, isTrue);
    await _pumpUntil(
      tester,
      () async => await centre() == _red,
      'a restart to reset the box to red',
    );
    _report(
      'hot restart ${services.run.lastRestart?.duration.inMilliseconds} ms',
    );

    // The app reads the clipboard on every tap and turns purple when it
    // holds "raccoon". Serve that one call from here, so the round trip
    // (app, runner, simulator, reply) is checked without the system clipboard.
    final client = services.sessions.session(name)?.client;
    var served = 0;
    client?.registerChannel(IdePlatformChannels.platformChannel, (data) async {
      const codec = JSONMethodCodec();
      final call = codec.decodeMethodCall(ByteData.sublistView(data));
      if (call.method != 'Clipboard.getData') {
        return const IdePlatformChannels().handlePlatform(data);
      }
      served++;
      final reply = codec.encodeSuccessEnvelope({'text': 'raccoon'});
      return reply.buffer.asUint8List(reply.offsetInBytes, reply.lengthInBytes);
    });
    await tester.tap(find.byType(RaccoonView));
    await _pumpUntil(
      tester,
      () async => await centre() == _purple,
      'the box to turn purple once the app read the clipboard',
    );
    expect(served, greaterThan(0));
    if (client != null) const IdePlatformChannels().register(client);
    _report('platform channel served by the simulator');

    await tester.tap(find.byKey(PresetBarFrame.keyOf(SizePreset.phone)));
    await _pumpUntil(
      tester,
      () => frame()?.width == 1170 && frame()?.height == 2532,
      'a 390×844 @3x frame',
    );
    await _screenshot(tester, '3-phone');

    // On the board the size belongs to the run: picked from the frame's
    // title, live (#89). The board keeps it for the next run; this one's
    // is not left behind.
    final saved = File(
      p.join(services.board.sizes?.directory ?? '', name, 'size'),
    );
    addTearDown(() {
      if (saved.existsSync()) saved.deleteSync();
    });
    await tester.tap(find.byKey(ToolbarFrame.boardKey));
    await tester.pump();
    await tester.tap(find.byKey(RaccoonBoard.sizeKey(name)));
    await tester.pump();
    await _screenshot(tester, '4-board-size-menu');
    await tester.tap(find.byKey(RaccoonBoard.sizeOptionKey(name, 'tablet')));
    await _pumpUntil(
      tester,
      () => frame()?.width == 1640 && frame()?.height == 2360,
      'a 820×1180 @2x frame on the board',
    );
    expect(saved.readAsStringSync(), '820x1180@2\n');
    await _screenshot(tester, '5-board-tablet');

    await tester.tap(find.byKey(DevicesButtonFrame.buttonKey));
    await tester.pump();
    expect(find.byType(DevicesMenuFrame), findsOneWidget);
    await _screenshot(tester, '6-devices', wholeView: true);
    await tester.tap(find.byKey(DevicesButtonFrame.buttonKey));
    await tester.pump();

    await tester.tap(find.byKey(ToolbarFrame.stopKey));
    await _pumpUntil(
      tester,
      () =>
          services.run.phase == RunPhase.idle &&
          services.sessions.session(name) == null,
      'the run and its runner to stop',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The simulator's log, printed when a wait times out.
RunLog? _log;

/// The app's centre colour now, printed when a wait times out.
Future<(int, int, int)?> Function()? _lastCentre;

Future<void> _pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      debugPrint(_log?.text);
      debugPrint('[e2e] centre colour: ${await _lastCentre?.call()}');
      fail('timed out waiting for $what');
    }
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  // Let the widgets catch up with the state the condition saw.
  await tester.pump();
}

/// The app's centre colour as (red, green, blue): from [frame] when it
/// carries pixels, else from the window, where a GPU buffer frame shows
/// through the host's texture and nowhere else.
Future<(int, int, int)?> _appCentre(
  WidgetTester tester,
  rc.Frame? frame,
) async {
  if (frame == null) return null;
  if (frame.pixels.isNotEmpty) return _centre(frame);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(SimulatorPage.windowKey),
  );
  final centre =
      tester.getCenter(find.byType(RaccoonView)) -
      boundary.localToGlobal(Offset.zero);
  final image = await boundary.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  image.dispose();
  if (bytes == null) return null;
  final offset = (centre.dy.round() * width + centre.dx.round()) * 4;
  return (
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

/// The colour at the frame's centre as (red, green, blue).
(int, int, int)? _centre(rc.Frame? frame) {
  if (frame == null || frame.pixels.isEmpty) return null;
  final offset = (frame.height ~/ 2) * frame.rowBytes + (frame.width ~/ 2) * 4;
  final pixels = frame.pixels;
  return switch (frame.format) {
    rc.PixelFormat.PIXEL_FORMAT_RGBA8888 => (
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
    ),
    _ => (pixels[offset + 2], pixels[offset + 1], pixels[offset]),
  };
}

void _report(String line) => debugPrint('[e2e] $line');

/// How the frame came: as a GPU buffer, from a shared buffer, or inline.
String _kindOf(rc.Frame? frame) => switch (frame) {
  null => 'none',
  rc.Frame(inGpuBuffer: true, gpuGeneration: final generation) =>
    '${frame.sequence} in GPU buffer ${frame.bufferIndex} of $generation',
  rc.Frame(inSharedBuffer: true) =>
    '${frame.sequence} in shared buffer ${frame.bufferIndex}',
  _ => '${frame.sequence} inline',
};

/// The window as a PNG in the screenshot folder; [wholeView] takes the
/// whole view, overlays such as an open menu included.
Future<void> _screenshot(
  WidgetTester tester,
  String name, {
  bool wholeView = false,
}) async {
  if (_screenshots.isEmpty) return;
  await tester.pump(const Duration(milliseconds: 100));
  final view = tester.binding.renderViews.first;
  final image = switch ((wholeView, view.debugLayer)) {
    // The view's layer works in physical pixels.
    (true, final OffsetLayer layer) => await layer.toImage(
      Offset.zero & view.size * tester.view.devicePixelRatio,
    ),
    _ =>
      await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(SimulatorPage.windowKey),
          )
          .toImage(),
  };
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  final file = File(p.join(_screenshots, '$name.png'))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
  _report('screenshot ${file.path}');
}
