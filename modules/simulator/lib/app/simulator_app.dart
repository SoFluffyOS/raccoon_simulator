import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/app/simulator_options.dart';
import 'package:simulator/app/simulator_services.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/ui.dart';

/// The simulator window. Owns [services] once given them: they are
/// initialised here and disposed with the widget.
class SimulatorApp extends StatefulWidget {
  const SimulatorApp({
    super.key,
    required this.services,
    this.options = const SimulatorOptions(),
  });

  final SimulatorServices services;
  final SimulatorOptions options;

  @override
  State<SimulatorApp> createState() => _SimulatorAppState();
}

class _SimulatorAppState extends State<SimulatorApp> {
  late final AppLifecycleListener _lifecycle;

  SimulatorServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    unawaited(_services.init(widget.options));
  }

  /// Stops a running app before the window closes, so neither the tool nor
  /// the runner outlives the simulator.
  Future<AppExitResponse> _onExitRequested() async {
    await _services.controller.stop();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _services.log),
        ChangeNotifierProvider.value(value: _services.run),
        ChangeNotifierProvider.value(value: _services.sessions),
        ChangeNotifierProvider.value(value: _services.runtime),
        ChangeNotifierProvider.value(value: _services.project),
        ChangeNotifierProvider.value(value: _services.viewer),
        Provider<SimulatorController>.value(value: _services.controller),
      ],
      child: WidgetsApp(
        title: 'Raccoon Simulator',
        color: Palette.accent,
        debugShowCheckedModeBanner: false,
        textStyle: Typography.body,
        builder: (context, _) => const SimulatorPage(),
      ),
    );
  }
}
