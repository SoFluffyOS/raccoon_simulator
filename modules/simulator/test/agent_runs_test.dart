import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/run/run.dart';

import 'support/fake_process.dart';

void main() {
  late RunLog log;
  late AgentRuns runs;
  late List<FlutterRunRequest> requests;
  late Map<String, FakeProcess> processes;

  setUp(() {
    log = RunLog();
    requests = [];
    processes = {};
    runs = AgentRuns(
      log: log,
      start: (request) async {
        requests.add(request);
        final process = processes[request.deviceId] = FakeProcess();
        return FlutterRun(process);
      },
      stopTimeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() => runs.dispose());

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  FakeProcess phone() => switch (processes['raccoon-phone']) {
    final process? => process,
    null => throw StateError('no phone run'),
  };

  Future<AgentRun> startPhone() async {
    final run = await runs.start(
      name: 'hello@phone',
      directory: '/work/hello',
      deviceId: 'raccoon-phone',
      flutter: '/sdk/bin/flutter',
      target: 'lib/main.dart',
    );
    phone()
      ..emitEvent('app.start', {
        'appId': 'a1',
        'deviceId': 'raccoon-phone',
        'supportsRestart': true,
      })
      ..emitEvent('app.debugPort', {'appId': 'a1', 'wsUri': 'ws://h:1/t=/ws'})
      ..emitEvent('app.started', {'appId': 'a1'});
    await pump();
    return run;
  }

  test('runs any project on any device, beside each other', () async {
    final phone = await startPhone();
    await phone.started;
    await runs.start(
      name: 'hello@tablet',
      directory: '/work/hello',
      deviceId: 'raccoon-tablet',
      flutter: '/sdk/bin/flutter',
    );
    expect(requests.first.arguments, [
      'run',
      '-d',
      'raccoon-phone',
      '--machine',
      '--target',
      'lib/main.dart',
    ]);
    expect(requests.last.arguments, [
      'run',
      '-d',
      'raccoon-tablet',
      '--machine',
    ]);
    expect(
      [for (final run in runs.runs) run.name],
      [
        'hello@phone',
        'hello@tablet',
      ],
    );
    expect(phone.phase, RunPhase.running);
    expect(phone.canRestart, isTrue);
    expect(phone.vmServiceUri, 'ws://h:1/t=/ws');
  });

  test('keeps the app\'s, the runner\'s and the tool\'s lines, and shows '
      'them in the log panel under the run\'s name', () async {
    await startPhone();
    phone()
      ..emitEvent('app.log', {'appId': 'a1', 'log': 'flutter: hi'})
      ..emitEvent('app.log', {
        'appId': 'a1',
        'log': '🦝 first frame 236 ms after launch',
      });
    await pump();
    final lines = runs.run('hello@phone')?.lines ?? const [];
    expect(
      [for (final line in lines) (line.source, line.text)],
      containsAllInOrder([
        (DeviceLogSource.tool, 'Started'),
        (DeviceLogSource.app, 'flutter: hi'),
        (DeviceLogSource.runner, '🦝 first frame 236 ms after launch'),
      ]),
    );
    expect(log.text, contains('[hello@phone] flutter: hi'));
  });

  test('a hot restart that fails says why', () async {
    await startPhone();
    final process = phone();
    final restart = runs.restart('hello@phone', full: true);
    final sent = await process.nextRequest();
    expect(sent['method'], 'app.restart');
    expect((sent['params'] as Map)['fullRestart'], isTrue);
    process.respond(
      sent['id'] as int,
      result: {'code': 1, 'message': 'lib/main.dart:3: Error'},
    );
    await expectLater(
      restart,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('lib/main.dart:3: Error'),
        ),
      ),
    );
  });

  test('a tool that exits before the app started fails the start, with '
      'its last lines', () async {
    final run = await runs.start(
      name: 'hello@phone',
      directory: '/work/hello',
      deviceId: 'raccoon-phone',
      flutter: 'flutter',
    );
    phone().emitError('Error: no pubspec');
    await pump();
    await phone().exit(1);
    await expectLater(
      run.started,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Error: no pubspec'),
        ),
      ),
    );
    expect(runs.run('hello@phone'), isNull);
  });

  test('stop asks the app to stop and the run goes', () async {
    await startPhone();
    final process = phone();
    final stopping = runs.stop('hello@phone');
    final sent = await process.nextRequest();
    expect(sent['method'], 'app.stop');
    process.respond(sent['id'] as int, result: true);
    await process.exit(0);
    await stopping;
    await pump();
    expect(runs.runs, isEmpty);
  });
}
