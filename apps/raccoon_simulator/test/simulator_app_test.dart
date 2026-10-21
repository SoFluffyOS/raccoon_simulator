import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/simulator.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('simulator_app'));
  tearDown(() => temp.deleteSync(recursive: true));

  HostInfo bareHost() => HostInfo(
    operatingSystem: 'linux',
    environment: {'HOME': temp.path, 'PATH': '', 'XDG_RUNTIME_DIR': temp.path},
    temporaryDirectory: temp.path,
    workingDirectory: temp.path,
    executable: p.join(temp.path, 'raccoon_simulator'),
  );

  testWidgets('a machine without the runtime shows what is missing', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1360, 880)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = SimulatorServices.create(
      host: bareHost(),
      settings: MemorySettingsStore(),
    );

    await tester.pumpWidget(SimulatorApp(services: services));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Waiting for your app'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(services.controller.runBlocker, isNotNull);
    expect(find.text('Set up'), findsOneWidget);
    expect(services.runtime.settingUp, isFalse, reason: 'no SDK to set up');
    for (final kind in CheckKind.values) {
      expect(find.text(kind.label), findsOneWidget);
    }
    expect(find.text('Private runner sockets'), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
