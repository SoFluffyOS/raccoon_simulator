import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';
import 'package:simulator/ui/ui.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/fake_runner.dart';
import 'support/watched_folder.dart';

void main() {
  late Directory temp;
  late SessionService sessions;
  late ProjectViewModel project;
  late RunLog log;
  late RunViewModel run;
  late ViewerViewModel viewer;
  late BoardViewModel board;
  late RuntimeViewModel runtime;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_viewer');
    sessions = SessionService(
      connect: RunnerClient.connect,
      reconnectDelay: const Duration(milliseconds: 50),
    );
    project = ProjectViewModel(settings: MemorySettingsStore());
    log = RunLog();
    run = RunViewModel(log: log);
    viewer = ViewerViewModel();
    board = BoardViewModel(settings: MemorySettingsStore());
    final host = HostInfo(
      operatingSystem: 'linux',
      environment: {'HOME': temp.path, 'PATH': ''},
      temporaryDirectory: temp.path,
      workingDirectory: temp.path,
      executable: p.join(temp.path, 'raccoon_simulator'),
    );
    runtime = RuntimeViewModel(
      host: host,
      settings: MemorySettingsStore(),
      doctor: RuntimeDoctor(host: host),
      fixer: RuntimeFixer(host: host),
      onLine: (_) {},
      locateSdk: (_) => null,
      locateCheckout: (_) => null,
    );
  });

  tearDown(() {
    sessions.dispose();
    project.dispose();
    run.dispose();
    log.dispose();
    viewer.dispose();
    board.dispose();
    runtime.dispose();
    temp.deleteSync(recursive: true);
  });

  Future<void> openProject(String name) async {
    final directory = Directory(p.join(temp.path, name))..createSync();
    File(p.join(directory.path, 'pubspec.yaml')).writeAsStringSync(
      'name: $name\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await project.open(directory.path);
  }

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: sessions),
      ChangeNotifierProvider.value(value: project),
      ChangeNotifierProvider.value(value: run),
      ChangeNotifierProvider.value(value: viewer),
      ChangeNotifierProvider.value(value: board),
      ChangeNotifierProvider.value(value: runtime),
    ],
    child: FluffyTheme(
      data: SimulatorTheme.data,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: ViewerFrame(),
      ),
    ),
  );

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('condition not met in time');
  }

  RunnerConnection shownConnection(WidgetTester tester) =>
      tester.widget<RaccoonView>(find.byType(RaccoonView)).connection;

  testWidgets('waits for an app to run from an editor', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Waiting for your app'), findsOneWidget);
  });

  testWidgets('points at setup when a check fails', (tester) async {
    runtime.refresh();
    await tester.pumpWidget(app());

    expect(find.text('Raccoon needs setup'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('shows an app run from an editor without a project', (
    tester,
  ) async {
    late FakeRunner editorRun;
    await tester.runAsync(() async {
      editorRun = await FakeRunner.start(
        p.join(temp.path, 'counter.sock'),
        pid: 4,
      );
      sessions.follow([watched(temp.path)]);
      await until(() => sessions.session('counter') != null);
    });
    await tester.pumpWidget(app());

    expect(shownConnection(tester), same(sessions.session('counter')?.client));

    await tester.runAsync(editorRun.stop);
    // A poll may still see the closing runner's socket for a moment, and
    // reconnect or count it as refused; the window settles once it is gone.
    final waiting = find.text('Waiting for your app');
    for (var i = 0; i < 100 && waiting.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(waiting, findsOneWidget);
    expect(sessions.shownApp(), isNull);
  });

  testWidgets('says to press Run while no runner serves the app', (
    tester,
  ) async {
    await tester.runAsync(() => openProject('hello'));
    await tester.pumpWidget(app());
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(RaccoonView), findsNothing);
  });

  testWidgets(
    'shows the live session by name, and the new one after a restart',
    (tester) async {
      final socket = p.join(temp.path, 'hello.sock');
      final runners = <FakeRunner>[];
      await tester.runAsync(() async {
        await openProject('hello');
        runners.add(await FakeRunner.start(socket, pid: 1));
        sessions.follow([watched(temp.path)]);
        await until(() => sessions.session('hello')?.pid == 1);
      });
      await tester.pumpWidget(app());
      final first = sessions.session('hello')?.client;
      expect(shownConnection(tester), same(first));

      await tester.runAsync(() async {
        await runners.first.stop();
        runners.add(await FakeRunner.start(socket, pid: 2));
        await until(() => sessions.session('hello')?.pid == 2);
      });
      await tester.pump();

      final second = sessions.session('hello')?.client;
      expect(second, isNot(same(first)));
      expect(shownConnection(tester), same(second));

      await tester.runAsync(() async {
        for (final runner in runners) {
          await runner.stop();
        }
      });
    },
  );

  testWidgets('the board shows every session, not just the shown app', (
    tester,
  ) async {
    final runners = <FakeRunner>[];
    await tester.runAsync(() async {
      await openProject('hello');
      runners.add(await FakeRunner.start(p.join(temp.path, 'hello.sock')));
      runners.add(
        await FakeRunner.start(p.join(temp.path, 'other@tablet.sock')),
      );
      sessions.follow([watched(temp.path)]);
      await until(() => sessions.sessions.length == 2);
    });
    await tester.pumpWidget(app());
    expect(find.byType(RaccoonView), findsOneWidget);
    expect(find.byType(BoardView), findsNothing);

    viewer.toggleBoard();
    await tester.pump();
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.byType(RaccoonView), findsNWidgets(2));
    expect(find.textContaining('Raccoon Tablet · other'), findsOneWidget);

    viewer.toggleBoard();
    await tester.pump();
    expect(find.byType(BoardView), findsNothing);
    expect(find.byType(RaccoonView), findsOneWidget);

    await tester.runAsync(() async {
      for (final runner in runners) {
        await runner.stop();
      }
    });
  });

  testWidgets('explains a runner another client holds', (tester) async {
    late FakeRunner busy;
    await tester.runAsync(() async {
      await openProject('hello');
      busy = await FakeRunner.start(
        p.join(temp.path, 'hello.sock'),
        refuse: true,
      );
      sessions.follow([watched(temp.path)]);
      await until(() => sessions.isRefused('hello'));
    });
    await tester.pumpWidget(app());
    expect(find.text('The runner is taken'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.runAsync(busy.stop);
  });
}
