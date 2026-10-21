import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/ui/frames/frames.dart';

/// The window, like a device simulator's: a compact toolbar over the app.
class SimulatorPage extends StatelessWidget {
  const SimulatorPage({super.key});

  /// Wraps the whole window, for screenshots.
  static const windowKey = ValueKey('simulator-window');

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      key: windowKey,
      child: ColoredBox(
        color: Palette.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToolbarFrame(),
            Expanded(child: ViewerFrame()),
          ],
        ),
      ),
    );
  }
}
