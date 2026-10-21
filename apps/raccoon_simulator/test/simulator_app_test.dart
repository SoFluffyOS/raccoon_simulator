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

  Future<SimulatorServices> open(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = SimulatorServices.create(
      host: bareHost(),
      settings: MemorySettingsStore(),
    );
    await tester.pumpWidget(SimulatorApp(services: services));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    return services;
  }

  testWidgets('a machine without the runtime points at setup', (
    tester,
  ) async {
    final services = await open(tester, const Size(1360, 880));

    expect(find.text('Raccoon needs setup'), findsOneWidget);
    expect(services.controller.runBlocker, isNotNull);
    expect(services.runtime.settingUp, isFalse, reason: 'no SDK to set up');
    expect(find.byKey(ToolbarFrame.runKey), findsNothing, reason: 'no project');
    for (final preset in SizePreset.all) {
      expect(find.byKey(PresetBarFrame.keyOf(preset)), findsOneWidget);
    }

    await tester.tap(find.byKey(ToolbarFrame.settingsKey));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);
    for (final kind in CheckKind.values) {
      expect(find.text(kind.label), findsOneWidget);
    }
    expect(find.text('Private runner sockets'), findsOneWidget);
    expect(find.text('Open…'), findsOneWidget);

    await tester.tap(find.byKey(SettingsDialog.closeKey));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a narrow window steps through the presets with one button', (
    tester,
  ) async {
    final services = await open(tester, const Size(480, 720));

    expect(find.byKey(PresetBarFrame.keyOf(SizePreset.phone)), findsNothing);
    await tester.tap(find.byKey(const ValueKey('preset-next')));
    await tester.pump();
    expect(services.viewer.preset, SizePreset.phone);

    await tester.pumpWidget(const SizedBox());
  });
}
