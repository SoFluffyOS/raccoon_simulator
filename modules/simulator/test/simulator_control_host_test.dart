import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';

import 'support/fake_process.dart';
import 'support/fake_runner.dart';
import 'support/watched_folder.dart';

void main() {
  late Directory temp;
  late FakeRunner runner;
  late SessionService sessions;
  late ViewerViewModel viewer;
  late BoardViewModel board;
  late RunLog log;
  late AgentRuns agentRuns;
  late RunViewModel hostRun;
  late SimulatorControlHost host;
  late RaccoonControl control;

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('condition not met in time');
  }

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('simulator_control');
    runner = await FakeRunner.start(p.join(temp.path, 'hello@phone.sock'));
    sessions = SessionService(connect: RunnerClient.connect);
    sessions.follow([watched(temp.path)]);
    viewer = ViewerViewModel();
    board = BoardViewModel(settings: MemorySettingsStore());
    log = RunLog();
    agentRuns = AgentRuns(
      log: log,
      start: (request) async => FlutterRun(FakeProcess()),
    );
    hostRun = RunViewModel(log: log);
    final info = HostInfo(
      operatingSystem: 'linux',
      environment: {'HOME': temp.path, 'PATH': ''},
      temporaryDirectory: temp.path,
      workingDirectory: temp.path,
      executable: '/usr/bin/raccoon_simulator',
    );
    host = SimulatorControlHost(
      sessions: sessions,
      hostRun: hostRun,
      agentRuns: agentRuns,
      runtime: RuntimeViewModel(
        host: info,
        settings: MemorySettingsStore(),
        doctor: RuntimeDoctor(host: info),
        fixer: RuntimeFixer(host: info),
        onLine: (_) {},
      ),
      board: board,
      viewer: viewer,
      log: log,
      environment: {'XDG_DATA_HOME': temp.path},
      stopHostRun: () async {},
    );
    control = RaccoonControl(host);
    await until(() => sessions.session('hello@phone') != null);
  });

  tearDown(() async {
    sessions.dispose();
    agentRuns.dispose();
    hostRun.dispose();
    await runner.stop();
    temp.deleteSync(recursive: true);
  });

  test('the apps are the board\'s sessions, under their devices', () async {
    final result = await control.call('list_devices', {});
    expect(result['host'], 'simulator');
    final device = (result['devices'] as List).single as Map;
    expect(device['id'], 'raccoon-phone');
    final app = (device['apps'] as List).single as Map;
    expect(app['name'], 'hello@phone');
    expect(app['started_by'], 'editor');
    expect(app['can_reload'], isFalse);
    // No view sized it yet: the board's frame for the phone.
    expect(app['size'], {'width': 390, 'height': 844, 'pixel_ratio': 3});
  });

  test('an action brings the board up and shows in the log', () async {
    expect(viewer.boardOn, isFalse);
    await control.call('tap', {'device': 'phone', 'x': 10, 'y': 20});
    expect(viewer.boardOn, isTrue);
    expect(log.text, contains('Agent: tap 10, 20 on hello@phone'));
  });

  test('a resize sizes the board\'s frame, as its size menu does', () async {
    final app = host.apps().single;
    await app.resize((width: 400, height: 700, pixelRatio: 2));
    final frame = board.frames.single;
    expect(frame.name, 'hello@phone');
    expect((frame.size, frame.pixelRatio), (const Size(400, 700), 2));
  });

  test('an app run elsewhere has no hot reload, and its log is the '
      'runner\'s', () async {
    await expectLater(
      control.call('hot_reload', {}),
      throwsA(
        isA<RaccoonControlError>().having((e) => e.code, 'code', 'unsupported'),
      ),
    );
    File(p.join(temp.path, 'raccoon', 'data', 'hello@phone', 'runner.log'))
      ..createSync(recursive: true)
      ..writeAsStringSync('12:00:00.000 🦝 first frame 9 ms after launch\n');
    final logs = await control.call('logs', {'source': 'runner'});
    expect((logs['lines'] as List).single, {
      'source': 'runner',
      'text': '12:00:00.000 🦝 first frame 9 ms after launch',
    });
  });

  test('a run waits for a runtime that can run', () async {
    await expectLater(
      control.call('run', {'project': temp.path, 'device': 'raccoon-phone'}),
      throwsA(
        isA<RaccoonControlError>().having(
          (e) => e.message,
          'message',
          'no Flutter SDK found',
        ),
      ),
    );
  });
}
