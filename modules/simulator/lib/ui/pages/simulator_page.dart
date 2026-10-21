import 'package:flutter/widgets.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/ui/frames/frames.dart';

/// The window: toolbar on top, project and runtime on the left, the app and
/// its log on the right, status at the bottom.
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
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Palette.border)),
                    ),
                    child: SizedBox(
                      width: Spacing.sidebarWidth,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [ProjectFrame(), RuntimeFrame()],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: ViewerFrame()),
                        SizedBox(height: Spacing.logHeight, child: LogFrame()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StatusBarFrame(),
          ],
        ),
      ),
    );
  }
}
