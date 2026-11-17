import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/session/session.dart';

import 'support/fake_runner.dart';
import 'support/watched_folder.dart';

void main() {
  late Directory temp;
  late SessionService sessions;
  late WindowVisibility visibility;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_visibility');
    sessions = SessionService(
      connect: RunnerClient.connect,
      reconnectDelay: const Duration(milliseconds: 50),
    );
    visibility = WindowVisibility(
      sessions: sessions,
      inUseFor: const Duration(milliseconds: 100),
    );
  });

  tearDown(() {
    visibility.dispose();
    sessions.dispose();
    temp.deleteSync(recursive: true);
  });

  /// Waits until [condition] holds, as sockets are asynchronous.
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('condition not met in time');
  }

  Future<FakeRunner> running(String name) async {
    final runner = await FakeRunner.start(p.join(temp.path, '$name.sock'));
    addTearDown(runner.stop);
    return runner;
  }

  const hidden = 'flutter/lifecycle AppLifecycleState.hidden';
  const resumed = 'flutter/lifecycle AppLifecycleState.resumed';

  test('the window hidden hides every app; shown again resumes them, and '
      'an unfocused window tells nothing', () async {
    final runner = await running('hello');
    sessions.follow([watched(temp.path)]);
    await until(() => sessions.session('hello') != null);

    visibility.windowChanged(AppLifecycleState.inactive);
    visibility.windowChanged(AppLifecycleState.hidden);
    await until(() => runner.appMessages.isNotEmpty);
    expect(runner.appMessages, [hidden]);

    visibility.windowChanged(AppLifecycleState.inactive);
    await until(() => runner.appMessages.length == 2);
    expect(runner.appMessages, [hidden, resumed]);
  });

  test('an app that comes while the window is hidden is hidden', () async {
    visibility.windowChanged(AppLifecycleState.hidden);
    final runner = await running('hello');
    sessions.follow([watched(temp.path)]);
    await until(() => runner.appMessages.isNotEmpty);
    expect(runner.appMessages, [hidden]);
  });

  test('an app an agent drives stays resumed for a while', () async {
    final runner = await running('hello');
    sessions.follow([watched(temp.path)]);
    await until(() => sessions.session('hello') != null);
    visibility.windowChanged(AppLifecycleState.hidden);
    await until(() => runner.appMessages.length == 1);

    visibility.use('hello');
    await until(() => runner.appMessages.length == 2);
    await until(() => runner.appMessages.length == 3);
    expect(runner.appMessages, [hidden, resumed, hidden]);
  });
}
