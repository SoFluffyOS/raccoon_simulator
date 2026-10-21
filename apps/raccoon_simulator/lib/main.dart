import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:simulator/simulator.dart';

/// `raccoon_simulator [project folder] [--run] [--no-setup]`
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = SimulatorServices.create(
    host: HostInfo.current(),
    settings: PreferencesSettingsStore(),
  );
  if (Platform.isMacOS) await MacWindow.setUp(services.chrome);
  runApp(
    SimulatorApp(
      services: services,
      options: SimulatorOptions.parse(arguments),
    ),
  );
}
