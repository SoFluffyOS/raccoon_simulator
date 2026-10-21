// Drives the real simulator window against the real runtime: opens a project
// (the runner's example/hello by default), runs it on Raccoon, taps its box
// through the viewport and checks the runner's next frames turn it green,
// hot reloads, hot restarts (the box is red again), answers the app's
// clipboard read over the platform channel (purple), switches to the phone
// preset, and stops.
//
//   flutter test integration_test/hello_e2e_test.dart -d <linux or macos> \
//     [--dart-define=RACCOON_E2E_PROJECT=<folder of a hello-like app>] \
//     [--dart-define=RACCOON_E2E_SCREENSHOTS=<folder for PNGs>]
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
    _lastCentre = () => _centre(frame());

    await _pumpUntil(
      tester,
      () => services.run.phase == RunPhase.running && frame() != null,
      'the app running with a frame',
      timeout: const Duration(minutes: 3),
    );
    await _pumpUntil(
      tester,
      () => _centre(frame()) == _red,
      'the red box',
    );
    expect(find.byType(RaccoonView), findsOneWidget);
    _report('launch ${services.run.launchTime?.inMilliseconds} ms');
    await _screenshot(tester, '1-running');

    await tester.tap(find.byType(RaccoonView));
    await _pumpUntil(
      tester,
      () => _centre(frame()) == _green,
      'the box to turn green after a tap',
    );
    await _screenshot(tester, '2-tapped');

    await tester.tap(find.text('Hot reload'));
    await _pumpUntil(
      tester,
      () => services.run.lastRestart?.kind == RestartKind.hotReload,
      'the hot reload',
    );
    expect(services.run.lastRestart?.succeeded, isTrue);
    expect(_centre(frame()), _green, reason: 'a reload keeps state');
    _report(
      'hot reload ${services.run.lastRestart?.duration.inMilliseconds} ms',
    );

    await tester.tap(find.text('Hot restart'));
    await _pumpUntil(
      tester,
      () => services.run.lastRestart?.kind == RestartKind.hotRestart,
      'the hot restart',
    );
    expect(services.run.lastRestart?.succeeded, isTrue);
    await _pumpUntil(
      tester,
      () => _centre(frame()) == _red,
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
      () => _centre(frame()) == _purple,
      'the box to turn purple once the app read the clipboard',
    );
    expect(served, greaterThan(0));
    if (client != null) const IdePlatformChannels().register(client);
    _report('platform channel served by the simulator');

    await tester.tap(find.text('Phone'));
    await _pumpUntil(
      tester,
      () => frame()?.width == 1170 && frame()?.height == 2532,
      'a 390×844 @3x frame',
    );
    await _screenshot(tester, '3-phone');

    await tester.tap(find.text('Stop'));
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
(int, int, int)? Function()? _lastCentre;

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      debugPrint(_log?.text);
      debugPrint('[e2e] centre colour: ${_lastCentre?.call()}');
      fail('timed out waiting for $what');
    }
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  // Let the widgets catch up with the state the condition saw.
  await tester.pump();
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

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (_screenshots.isEmpty) return;
  await tester.pump(const Duration(milliseconds: 100));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(SimulatorPage.windowKey),
  );
  final image = await boundary.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  final file = File(p.join(_screenshots, '$name.png'))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
  _report('screenshot ${file.path}');
}
