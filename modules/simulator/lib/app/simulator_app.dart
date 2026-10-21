import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/app/simulator_options.dart';
import 'package:simulator/app/simulator_services.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/ui.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

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
  final _signals = <StreamSubscription<ProcessSignal>>[];
  final _screenSize = ScreenSizeNotifier();

  SimulatorServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    _watchSignals();
    unawaited(_services.init(widget.options));
  }

  /// Keeps [_screenSize] on the window's size class as it resizes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = ScreenSize.of(context);
    if (size == _screenSize.screenSize) return;
    _screenSize.updateScreenSize(size);
  }

  /// SIGTERM and SIGINT end the process without an exit request, which
  /// would leave the tool and the runner running; stop them first.
  void _watchSignals() {
    if (Platform.isWindows) return;
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
      _signals.add(signal.watch().listen((_) => unawaited(_exitOnSignal())));
    }
  }

  Future<void> _exitOnSignal() async {
    await _services.controller.stop();
    exit(0);
  }

  /// Stops a running app before the window closes, so neither the tool nor
  /// the runner outlives the simulator.
  Future<AppExitResponse> _onExitRequested() async {
    await _services.controller.stop();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    for (final signal in _signals) {
      unawaited(signal.cancel());
    }
    _lifecycle.dispose();
    _screenSize.dispose();
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
        ChangeNotifierProvider.value(value: _screenSize),
        ChangeNotifierProvider.value(value: _services.chrome),
        Provider<SimulatorController>.value(value: _services.controller),
      ],
      child: FluffyTheme(
        data: SimulatorTheme.data,
        child: WidgetsApp(
          title: 'Raccoon Simulator',
          color: Palette.accent,
          debugShowCheckedModeBanner: false,
          textStyle: SimulatorTheme.data.typography.base2.copyWith(
            color: Palette.text,
          ),
          // A navigator, for the settings dialog.
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          home: const SimulatorPage(),
        ),
      ),
    );
  }
}
