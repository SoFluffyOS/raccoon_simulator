import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/session/session.dart';

import 'support/fake_runner.dart';
import 'support/watched_folder.dart';

void main() {
  late Directory temp;
  late SessionService service;
  late List<RunnerClient> connected;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_sessions');
    connected = [];
    service = SessionService(
      connect: RunnerClient.connect,
      onConnected: connected.add,
      reconnectDelay: const Duration(milliseconds: 50),
    );
  });

  tearDown(() {
    service.dispose();
    temp.deleteSync(recursive: true);
  });

  String socket(String name) => p.join(temp.path, '$name.sock');

  /// Waits until [condition] holds, as the directory watch is asynchronous.
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('condition not met in time');
  }

  test('connects to a runner and finds it by app name', () async {
    final runner = await FakeRunner.start(socket('hello'), pid: 11);
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);

    await until(() => service.session('hello') != null);

    final session = service.session('hello');
    expect(session?.name, 'hello');
    expect(session?.pid, 11);
    expect(service.session('other'), isNull);
    expect(connected, hasLength(1));
  });

  test(
    'a runner restarted under the same name replaces the session',
    () async {
      final first = await FakeRunner.start(socket('hello'), pid: 1);
      service.follow([watched(temp.path)]);
      await until(() => service.session('hello')?.pid == 1);
      final before = service.session('hello');

      await first.stop();
      final second = await FakeRunner.start(socket('hello'), pid: 2);
      addTearDown(second.stop);

      await until(() => service.session('hello')?.pid == 2);
      final after = service.session('hello');
      expect(after, isNot(same(before)));
      expect(after?.client, isNot(same(before?.client)));
      expect(second.connections, 1);
    },
  );

  test('reconnects when a runner hangs up but its socket stays', () async {
    final runner = await FakeRunner.start(socket('hello'), pid: 5);
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);
    await until(() => service.session('hello') != null);
    final before = service.session('hello');

    runner.dropClients();

    await until(() {
      final now = service.session('hello');
      return now != null && !identical(now, before);
    });
    expect(runner.connections, 2);
  });

  test('a session ends when its runner goes away', () async {
    final runner = await FakeRunner.start(socket('hello'));
    service.follow([watched(temp.path)]);
    await until(() => service.session('hello') != null);

    await runner.stop();

    await until(() => service.session('hello') == null);
    expect(service.sessions, isEmpty);
  });

  test('a runner held by another client is marked refused', () async {
    final runner = await FakeRunner.start(socket('hello'), refuse: true);
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);

    await until(() => service.isRefused('hello'));
    expect(service.session('hello'), isNull);
    expect(connected, isEmpty);
  });

  test('a runner that says another client has it is marked refused', () async {
    // What the runner says now, before it hangs up (#91): the hello fails
    // with RunnerBusy, which went uncaught.
    final runner = await FakeRunner.start(socket('hello'), busyWith: 42);
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);

    await until(() => service.isRefused('hello'));
    expect(service.session('hello'), isNull);
    expect(connected, isEmpty);
  });

  test('retry connects once the other client let go', () async {
    final busy = await FakeRunner.start(socket('hello'), refuse: true);
    service.follow([watched(temp.path)]);
    await until(() => service.isRefused('hello'));

    await busy.stop();
    final free = await FakeRunner.start(socket('hello'), pid: 3);
    addTearDown(free.stop);
    await service.retry();

    await until(() => service.session('hello')?.pid == 3);
    expect(service.isRefused('hello'), isFalse);
  });

  test('following another directory drops the old sessions', () async {
    final runner = await FakeRunner.start(socket('hello'));
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);
    await until(() => service.session('hello') != null);

    final other = Directory(p.join(temp.path, 'private'))..createSync();
    service.follow([watched(other.path)]);

    expect(service.session('hello'), isNull);
    expect(service.directories, [other.path]);
  });

  test('follows an editor run and the simulator run side by side', () async {
    final private = Directory(p.join(temp.path, 'private'))..createSync();
    final editorRun = await FakeRunner.start(socket('counter'), pid: 7);
    final ownRun = await FakeRunner.start(
      p.join(private.path, 'hello.sock'),
      pid: 8,
    );
    addTearDown(() async {
      await editorRun.stop();
      await ownRun.stop();
    });

    service.follow([watched(private.path), watched(temp.path)]);

    await until(
      () =>
          service.session('counter') != null &&
          service.session('hello') != null,
    );
    expect(service.directories, [private.path, temp.path]);
    expect(service.session('counter')?.pid, 7);
    expect(service.session('hello')?.pid, 8);
  });

  test('following the same directories again keeps the sessions', () async {
    final runner = await FakeRunner.start(socket('hello'));
    addTearDown(runner.stop);
    service.follow([watched(temp.path)]);
    await until(() => service.session('hello') != null);
    final before = service.session('hello');

    service.follow([watched(temp.path), watched(temp.path)]);

    expect(service.session('hello'), same(before));
    expect(service.directories, [temp.path]);
  });

  test('the latest session is the app connected last', () async {
    final first = await FakeRunner.start(socket('first'), pid: 1);
    addTearDown(first.stop);
    service.follow([watched(temp.path)]);
    await until(() => service.latest?.name == 'first');

    final second = await FakeRunner.start(socket('second'), pid: 2);
    addTearDown(second.stop);

    await until(() => service.latest?.name == 'second');
    await second.stop();
    await until(() => service.latest?.name == 'first');
  });

  test('shownApp prefers the run, then the project, then the latest', () async {
    expect(service.shownApp(), isNull);
    expect(service.shownApp(project: 'hello'), 'hello');

    final editorRun = await FakeRunner.start(socket('counter'));
    addTearDown(editorRun.stop);
    service.follow([watched(temp.path)]);
    await until(() => service.latest != null);

    expect(service.shownApp(), 'counter');
    expect(service.shownApp(project: 'hello'), 'counter');
    expect(service.shownApp(running: 'hello', project: 'hello'), 'hello');

    final projectRun = await FakeRunner.start(socket('hello'));
    addTearDown(projectRun.stop);
    await until(() => service.session('hello') != null);

    expect(service.shownApp(project: 'hello'), 'hello');
  });

  test('a refused editor run is shown so its message appears', () async {
    final busy = await FakeRunner.start(socket('counter'), refuse: true);
    addTearDown(busy.stop);
    service.follow([watched(temp.path)]);

    await until(() => service.refusedName == 'counter');
    expect(service.shownApp(), 'counter');
  });

  test('expectFresh skips a stale runner until a new socket appears', () async {
    final stale = await FakeRunner.start(socket('hello'), pid: 1);
    service.follow([watched(temp.path)]);
    await until(() => service.session('hello')?.pid == 1);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    service.expectFresh('hello', since: DateTime.now());
    await until(() => service.session('hello') == null);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(service.session('hello'), isNull, reason: 'the old socket is stale');

    // The new runner replaces the socket while the stale one keeps running.
    File(socket('hello')).deleteSync();
    final fresh = await FakeRunner.start(socket('hello'), pid: 2);
    addTearDown(() async {
      await fresh.stop();
      await stale.stop();
    });

    await until(() => service.session('hello')?.pid == 2);
  });

  // #132: one task that threw stopped every task after it.
  test('a connect that fails oddly does not stop later ones', () async {
    var attempts = 0;
    final flaky = SessionService(
      connect: (endpoint) {
        attempts++;
        if (attempts == 1) throw StateError('not a socket error');
        return RunnerClient.connect(endpoint);
      },
      reconnectDelay: const Duration(milliseconds: 50),
    );
    addTearDown(flaky.dispose);
    final runner = await FakeRunner.start(socket('hello'), pid: 7);
    addTearDown(runner.stop);
    flaky.follow([watched(temp.path)]);
    await until(() => attempts == 1);
    await flaky.retry().then((_) {}, onError: (Object _) {});

    await until(() => flaky.session('hello') != null);
    expect(flaky.session('hello')?.pid, 7);
  });
}
