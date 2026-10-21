import 'package:flutter/widgets.dart';
import 'package:simulator/simulator.dart';

/// `raccoon_simulator [project folder] [--run]`
void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final services = SimulatorServices.create(
    host: HostInfo.current(),
    settings: PreferencesSettingsStore(),
  );
  runApp(
    SimulatorApp(
      services: services,
      options: SimulatorOptions.parse(arguments),
    ),
  );
}
