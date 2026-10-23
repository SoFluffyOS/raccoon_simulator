import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/runtime.dart';
import 'package:simulator/services/services.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

void main() {
  late Directory temp;
  late CustomDevicesFile devices;
  late RuntimeViewModel runtime;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('simulator_devices');
    final checkout = CheckoutPaths(p.join(temp.path, 'repo'));
    for (final path in [checkout.deviceHelper, checkout.runnerBinary]) {
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
    }
    final host = HostInfo(
      operatingSystem: 'linux',
      environment: {'HOME': temp.path, 'PATH': ''},
      temporaryDirectory: temp.path,
      workingDirectory: checkout.root,
      executable: '/usr/bin/raccoon_simulator',
    );
    devices = CustomDevicesFile(p.join(temp.path, 'custom_devices.json'));
    runtime = RuntimeViewModel(
      host: host,
      settings: MemorySettingsStore(),
      doctor: RuntimeDoctor(host: host, devices: devices),
      fixer: RuntimeFixer(host: host, devices: devices),
      onLine: (_) {},
      locateSdk: (_) => null,
      locateCheckout: (_) => checkout,
    )..refresh();
    // raccoon itself, as setup leaves it, and an extra from an older one.
    for (final device in [RaccoonDevice.host, RaccoonDevice.phone]) {
      final runner = runtime.runner;
      if (runner == null) fail('no runner');
      RuntimeFixer(host: host, devices: devices).addDevice(device, runner);
    }
    runtime.refresh();
  });

  tearDown(() {
    runtime.dispose();
    temp.deleteSync(recursive: true);
  });

  Widget menu() => ChangeNotifierProvider.value(
    value: runtime,
    child: FluffyTheme(
      data: SimulatorTheme.data,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: DevicesMenuFrame(),
      ),
    ),
  );

  testWidgets('a switch puts a device in the picker', (tester) async {
    await tester.pumpWidget(menu());
    expect(runtime.deviceIds, ['raccoon', 'raccoon-phone']);

    await tester.tap(
      find.descendant(
        of: find.byKey(DevicesMenuFrame.switchKey('raccoon-tablet')),
        matching: find.byType(SwitchToggle),
      ),
    );
    // The switch says so once its tap settles.
    await tester.pumpAndSettle();
    expect(runtime.deviceIds, ['raccoon', 'raccoon-phone', 'raccoon-tablet']);
  });

  testWidgets('keep only Raccoon takes the extras out', (tester) async {
    await tester.pumpWidget(menu());
    expect(
      find.text('Keep only Raccoon (1 more in the picker)'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(DevicesMenuFrame.keepOnlyKey));
    await tester.pump();
    expect(runtime.deviceIds, ['raccoon']);
    expect(devices.ids(), ['raccoon']);
    expect(find.byKey(DevicesMenuFrame.keepOnlyKey), findsNothing);
  });
}
