import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/run/run.dart';

import 'support/fake_process.dart';

void main() {
  late FakeProcess process;
  late RunLog log;
  late RunViewModel viewModel;
  late List<FlutterRunRequest> requests;

  setUp(() {
    process = FakeProcess();
    log = RunLog();
    requests = [];
    viewModel = RunViewModel(
      log: log,
      start: (request) async {
        requests.add(request);
        return FlutterRun(process);
      },
      stopTimeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() => viewModel.dispose());

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  Future<void> startApp() async {
    await viewModel.run(
      directory: '/work/hello',
      appName: 'hello',
      flutter: '/sdk/bin/flutter',
      environment: const {'XDG_RUNTIME_DIR': '/run/user/1/raccoon_simulator'},
    );
    process
      ..emitEvent('daemon.connected', {'version': '0.6.1', 'pid': 1})
      ..emitEvent('app.start', {
        'appId': 'a1',
        'deviceId': 'raccoon',
        'supportsRestart': true,
      })
      ..emitEvent('app.debugPort', {'appId': 'a1', 'wsUri': 'ws://h:1/t=/ws'})
      ..emitEvent('app.started', {'appId': 'a1'});
    await pump();
  }

  test('starts flutter run -d raccoon --machine in the project', () async {
    await viewModel.run(
      directory: '/work/hello',
      appName: 'hello',
      flutter: '/sdk/bin/flutter',
      environment: const {'A': 'b'},
    );
    expect(viewModel.phase, RunPhase.starting);
    expect(viewModel.appName, 'hello');
    expect(requests.single.flutter, '/sdk/bin/flutter');
    expect(requests.single.directory, '/work/hello');
    expect(requests.single.arguments, ['run', '-d', 'raccoon', '--machine']);
    expect(requests.single.environment, {'A': 'b'});
  });

  test('is running after app.started, with the launch time', () async {
    await startApp();
    expect(viewModel.phase, RunPhase.running);
    expect(viewModel.appId, 'a1');
    expect(viewModel.vmServiceUri, 'ws://h:1/t=/ws');
    expect(viewModel.launchTime, isNotNull);
    expect(viewModel.canRestart, isTrue);
  });

  test('shows progress while starting', () async {
    await viewModel.run(directory: '/p', appName: 'p', flutter: 'flutter');
    process.emitEvent('app.progress', {
      'appId': 'a1',
      'id': '0',
      'message': 'Launching lib/main.dart on Raccoon in debug mode...',
      'finished': false,
    });
    await pump();
    expect(viewModel.progress, startsWith('Launching'));
  });

  test('logs plain lines as app output and stderr as errors', () async {
    await startApp();
    process
      ..emit('tapped')
      ..emitError('warning: something');
    await pump();
    final app = log.lines.where((line) => line.source == LogSource.app);
    expect(app.map((line) => line.text), contains('tapped'));
    final errors = log.lines.where((line) => line.source == LogSource.error);
    expect(errors.map((line) => line.text), contains('warning: something'));
  });

  test(
    'hot reload sends app.restart without fullRestart and times it',
    () async {
      await startApp();
      final request = process.nextRequest();
      final restart = viewModel.restart(RestartKind.hotReload);
      expect(viewModel.restarting, RestartKind.hotReload);
      expect(viewModel.canRestart, isFalse);
      final sent = await request;
      expect(sent['method'], 'app.restart');
      expect(sent['params'], {
        'appId': 'a1',
        'fullRestart': false,
        'pause': false,
        'reason': 'manual',
      });
      process.respond(sent['id'] as int, result: {'code': 0, 'message': ''});
      await restart;
      expect(viewModel.restarting, isNull);
      expect(viewModel.lastRestart?.kind, RestartKind.hotReload);
      expect(viewModel.lastRestart?.succeeded, isTrue);
    },
  );

  test('hot restart sends fullRestart true and reports failures', () async {
    await startApp();
    final request = process.nextRequest();
    final restart = viewModel.restart(RestartKind.hotRestart);
    final sent = await request;
    expect((sent['params'] as Map)['fullRestart'], isTrue);
    process.respond(
      sent['id'] as int,
      result: {'code': 1, 'message': 'Compilation failed'},
    );
    await restart;
    expect(viewModel.lastRestart?.succeeded, isFalse);
    expect(viewModel.lastRestart?.failure, 'Compilation failed');
    expect(viewModel.error, contains('Compilation failed'));
  });

  test('ignores restarts before the app started', () async {
    await viewModel.run(directory: '/p', appName: 'p', flutter: 'flutter');
    await viewModel.restart(RestartKind.hotReload);
    expect(process.written, isEmpty);
    expect(viewModel.lastRestart, isNull);
  });

  test('stop sends app.stop and goes idle when the tool exits', () async {
    await startApp();
    final request = process.nextRequest();
    final stop = viewModel.stop();
    expect(viewModel.phase, RunPhase.stopping);
    final sent = await request;
    expect(sent['method'], 'app.stop');
    expect(sent['params'], {'appId': 'a1'});
    process
      ..respond(sent['id'] as int, result: true)
      ..emitEvent('app.stop', {'appId': 'a1'});
    await pump();
    await process.exit(0);
    await stop;
    await pump();
    expect(viewModel.phase, RunPhase.idle);
    expect(viewModel.appId, isNull);
    expect(viewModel.error, isNull);
    expect(process.killed, isFalse);
  });

  test('stop kills the tool when it does not exit in time', () async {
    await viewModel.run(directory: '/p', appName: 'p', flutter: 'flutter');
    await viewModel.stop();
    await pump();
    expect(process.killed, isTrue);
    expect(viewModel.phase, RunPhase.idle);
  });

  test('an unexpected exit is an error and ends the run', () async {
    await startApp();
    await process.exit(1);
    await pump();
    expect(viewModel.phase, RunPhase.idle);
    expect(viewModel.error, contains('exited with code 1'));
  });

  test('a tool that cannot start leaves the run idle with an error', () async {
    final failing = RunViewModel(
      log: log,
      start: (_) async => throw const FormatException('no such file'),
    );
    addTearDown(failing.dispose);
    await failing.run(directory: '/p', appName: 'p', flutter: '/nope');
    expect(failing.phase, RunPhase.idle);
    expect(failing.error, contains('no such file'));
  });
}
