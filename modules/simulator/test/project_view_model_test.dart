import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/features/project/project.dart';
import 'package:simulator/services/services.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('simulator_project'));
  tearDown(() => temp.deleteSync(recursive: true));

  String project(String name, {bool flutter = true}) {
    final directory = Directory(p.join(temp.path, name))..createSync();
    File(p.join(directory.path, 'pubspec.yaml')).writeAsStringSync(
      'name: $name\n'
      'dependencies:\n'
      '${flutter ? '  flutter:\n    sdk: flutter\n' : '  path: any\n'}',
    );
    return directory.path;
  }

  test('reads the app name the runner socket is named after', () {
    final read = ProjectReader.read(project('hello'));
    expect(read.appName, 'hello');
    expect(read.folderName, 'hello');
  });

  test('refuses folders that are not Flutter apps', () {
    expect(
      () => ProjectReader.read(project('tool', flutter: false)),
      throwsA(isA<ProjectError>()),
    );
    expect(
      () => ProjectReader.read(temp.path),
      throwsA(isA<ProjectError>()),
    );
  });

  test('opening a project puts it first in the recent list', () async {
    final settings = MemorySettingsStore();
    final viewModel = ProjectViewModel(settings: settings, maxRecent: 2);
    addTearDown(viewModel.dispose);
    final a = project('a');
    final b = project('b');
    final c = project('c');

    await viewModel.open(a);
    await viewModel.open(b);
    await viewModel.open(a);
    expect(viewModel.recent, [a, b]);

    await viewModel.open(c);
    expect(viewModel.project?.appName, 'c');
    expect(viewModel.recent, [c, a]);
    expect(await settings.recentProjects(), [c, a]);
  });

  test('remembers recent projects across launches', () async {
    final a = project('a');
    final settings = MemorySettingsStore(recent: [a]);
    final viewModel = ProjectViewModel(settings: settings);
    addTearDown(viewModel.dispose);

    await viewModel.init();

    expect(viewModel.recent, [a]);
    expect(viewModel.project, isNull);
  });

  test('a bad folder keeps the current project and says why', () async {
    final viewModel = ProjectViewModel(settings: MemorySettingsStore());
    addTearDown(viewModel.dispose);
    await viewModel.open(project('good'));

    await viewModel.open(temp.path);

    expect(viewModel.project?.appName, 'good');
    expect(viewModel.error, contains('No pubspec.yaml'));
  });

  test('pick opens the chosen folder, and cancel does nothing', () async {
    String? chosen = project('picked');
    final viewModel = ProjectViewModel(
      settings: MemorySettingsStore(),
      pickDirectory: () async => chosen,
    );
    addTearDown(viewModel.dispose);

    await viewModel.pick();
    expect(viewModel.project?.appName, 'picked');

    chosen = null;
    await viewModel.pick();
    expect(viewModel.project?.appName, 'picked');
  });

  test('a camera picture is kept per project and goes to its runs', () async {
    final settings = MemorySettingsStore();
    String? chosen = p.join(temp.path, 'qr.png');
    final viewModel = ProjectViewModel(
      settings: settings,
      pickPicture: () async => chosen,
    );
    addTearDown(viewModel.dispose);
    final a = project('a');
    final b = project('b');

    // Nothing to keep it with before a project is open.
    await viewModel.pickCameraSource();
    expect(viewModel.cameraSource, isNull);

    await viewModel.open(a);
    expect(viewModel.runEnvironment, isEmpty);
    await viewModel.pickCameraSource();
    expect(viewModel.cameraSource, chosen);
    expect(viewModel.runEnvironment, {'RACCOON_CAMERA_SOURCE': chosen});

    // Cancelling keeps the picture.
    final kept = chosen;
    chosen = null;
    await viewModel.pickCameraSource();
    expect(viewModel.cameraSource, kept);

    await viewModel.open(b);
    expect(viewModel.cameraSource, isNull);
    await viewModel.open(a);
    expect(viewModel.cameraSource, kept);

    await viewModel.clearCameraSource();
    expect(viewModel.cameraSource, isNull);
    expect(await settings.cameraSource(a), isNull);
  });
}
