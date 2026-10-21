import 'package:flutter/widgets.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/viewer/models/models.dart';

/// The hosted app at [preset]'s size: the whole viewport for Fit, else the
/// device's logical size at its pixel ratio, scaled down to fit.
class AppViewport extends StatelessWidget {
  const AppViewport({
    super.key,
    required this.connection,
    required this.preset,
  });

  /// Wraps exactly the app's pixels, for screenshots.
  static const screenKey = ValueKey('simulator-screen');

  final RunnerConnection connection;
  final SizePreset preset;

  @override
  Widget build(BuildContext context) {
    final screen = RepaintBoundary(
      key: screenKey,
      child: RaccoonView(
        connection: connection,
        pixelRatio: preset.pixelRatio,
      ),
    );
    final size = preset.size;
    if (size == null) return screen;
    return Padding(
      padding: const EdgeInsets.all(Spacing.d16),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(color: Palette.border),
            ),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: screen,
            ),
          ),
        ),
      ),
    );
  }
}
