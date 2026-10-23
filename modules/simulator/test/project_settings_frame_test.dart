import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/project/project.dart';
import 'package:simulator/features/run/run.dart';
import 'package:simulator/services/services.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

void main() {
  late Directory temp;
  late ProjectViewModel project;
  late RunViewModel run;
  late String picture;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_project_frame');
    picture = p.join(temp.path, 'qr.png');
    project = ProjectViewModel(
      settings: MemorySettingsStore(),
      pickPicture: () async => picture,
    );
    run = RunViewModel(log: RunLog());
  });

  tearDown(() {
    project.dispose();
    run.dispose();
    temp.deleteSync(recursive: true);
  });

  Future<void> open(String name) async {
    final directory = Directory(p.join(temp.path, name))..createSync();
    File(p.join(directory.path, 'pubspec.yaml')).writeAsStringSync(
      'name: $name\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await project.open(directory.path);
  }

  Widget frame() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: project),
      ChangeNotifierProvider.value(value: run),
    ],
    child: FluffyTheme(
      data: SimulatorTheme.data,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(child: ProjectSettingsFrame()),
      ),
    ),
  );

  testWidgets('no camera row until a project is open', (tester) async {
    await tester.pumpWidget(frame());
    expect(find.byType(CameraSourceRow), findsNothing);
  });

  testWidgets('the camera row picks a picture and goes back to the pattern', (
    tester,
  ) async {
    await tester.runAsync(() => open('app'));
    await tester.pumpWidget(frame());
    expect(find.text('Test pattern'), findsOneWidget);

    await tester.tap(find.byKey(CameraSourceRow.pickKey));
    await tester.pump();
    expect(project.cameraSource, picture);
    expect(find.text('qr.png'), findsOneWidget);

    await tester.tap(find.byKey(CameraSourceRow.clearKey));
    await tester.pump();
    expect(project.cameraSource, isNull);
    expect(find.text('Test pattern'), findsOneWidget);
  });
}
