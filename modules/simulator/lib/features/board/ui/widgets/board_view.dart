import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:raccoon_view/raccoon_view.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/board/view_models/view_models.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A session as the board shows it.
final class BoardSession {
  const BoardSession({
    required this.name,
    required this.connection,
    this.onClose,
  });

  final String name;
  final RunnerConnection connection;
  final VoidCallback? onClose;
}

/// Every running device on one canvas: a dot grid that pans and zooms, one
/// frame per session with the device's name and size on it. Drag a frame
/// by its title, or hold Alt (Option on macOS) and grab it anywhere; pull
/// the corner handle to resize, and the app relayouts as it goes. Scroll
/// pans, Ctrl and scroll zooms, dragging the empty board pans.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.sessions, required this.viewModel});

  final List<BoardSession> sessions;
  final BoardViewModel viewModel;

  static ValueKey<String> titleKey(String name) =>
      ValueKey('board-title-$name');
  static ValueKey<String> grabKey(String name) => ValueKey('board-grab-$name');
  static ValueKey<String> resizeKey(String name) =>
      ValueKey('board-resize-$name');
  static ValueKey<String> closeKey(String name) =>
      ValueKey('board-close-$name');

  static const titleHeight = 28.0;
  static const handleSize = 16.0;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  Offset _pan = Offset.zero;
  double _zoom = 1;
  bool _altHeld = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.viewModel.addListener(_changed);
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    if (old.viewModel != widget.viewModel) {
      old.viewModel.removeListener(_changed);
      widget.viewModel.addListener(_changed);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.viewModel.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool _onKey(KeyEvent event) {
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (alt != _altHeld && mounted) setState(() => _altHeld = alt);
    return false;
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      if (HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed) {
        // Zoom about the pointer, so what is under it stays put.
        final factor = event.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
        final next = (_zoom * factor).clamp(0.25, 3.0);
        final local = event.localPosition;
        _pan = local - (local - _pan) * (next / _zoom);
        _zoom = next;
      } else {
        _pan -= event.scrollDelta;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onScroll,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanUpdate: (details) => setState(() => _pan += details.delta),
              child: CustomPaint(
                painter: _BoardGridPainter(
                  ink: Palette.border,
                  pan: _pan,
                  zoom: _zoom,
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()
                ..translateByDouble(_pan.dx, _pan.dy, 0, 1)
                ..scaleByDouble(_zoom, _zoom, 1, 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final session in widget.sessions)
                    _frame(context, session),
                ],
              ),
            ),
            if (widget.sessions.isEmpty)
              Center(
                child: Text(
                  'Run the project on raccoon, raccoon-phone, raccoon-tablet '
                  'or raccoon-desktop from your editor: each shows up here.',
                  style: context.fluffyTheme.typography.base2.copyWith(
                    color: Palette.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _frame(BuildContext context, BoardSession session) {
    final frame = widget.viewModel.frameFor(session.name);
    final typography = context.fluffyTheme.typography;
    // Each step starts from where the frame is now, not where this build
    // put it: steps can land between frames. The deltas come in board
    // units already: the detectors sit under the zoom.
    void moveBy(Offset delta) {
      final current = widget.viewModel.frameFor(session.name);
      widget.viewModel.move(session.name, current.position + delta);
    }

    void resizeBy(Offset delta) {
      final current = widget.viewModel.frameFor(session.name);
      widget.viewModel.resize(
        session.name,
        Size(current.size.width + delta.dx, current.size.height + delta.dy),
      );
    }

    return Positioned(
      left: frame.position.dx,
      top: frame.position.dy - BoardView.titleHeight,
      width: frame.size.width,
      height: frame.size.height + BoardView.titleHeight,
      child: Column(
        children: [
          // The title: the device, the project, the size; drag it to move.
          GestureDetector(
            key: BoardView.titleKey(session.name),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanUpdate: (details) => moveBy(details.delta),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                height: BoardView.titleHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${frame.device} · ${frame.project} · ${frame.label}',
                        style: typography.caption2.copyWith(
                          color: Palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.onClose case final onClose?)
                      GestureDetector(
                        key: BoardView.closeKey(session.name),
                        onTap: onClose,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(Spacing.d4),
                            child: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.border),
                  ),
                  child: RaccoonView(
                    connection: session.connection,
                    pixelRatio: frame.pixelRatio,
                  ),
                ),
                // Alt held: the whole frame is a handle, the app gets nothing.
                if (_altHeld)
                  Positioned.fill(
                    child: GestureDetector(
                      key: BoardView.grabKey(session.name),
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanUpdate: (details) => moveBy(details.delta),
                      child: const MouseRegion(cursor: SystemMouseCursors.grab),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: BoardView.resizeKey(session.name),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onPanUpdate: (details) => resizeBy(details.delta),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: CustomPaint(
                        size: Size.square(BoardView.handleSize),
                        painter: _HandlePainter(Palette.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid in screen space: it moves with the pan and spreads with the
/// zoom, so the board reads as one surface.
class _BoardGridPainter extends CustomPainter {
  const _BoardGridPainter({
    required this.ink,
    required this.pan,
    required this.zoom,
  });

  final Color ink;
  final Offset pan;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = 24.0 * zoom;
    if (spacing < 6) return;
    final paint = Paint()..color = ink;
    final startX = pan.dx % spacing;
    final startY = pan.dy % spacing;
    for (var x = startX; x <= size.width; x += spacing) {
      for (var y = startY; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BoardGridPainter old) =>
      old.pan != pan || old.zoom != zoom || old.ink != ink;
}

/// Two short diagonals in the corner: the usual sign for a resize grip.
class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width - 2, 6),
      Offset(6, size.height - 2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 2, 11),
      Offset(11, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.ink != ink;
}
