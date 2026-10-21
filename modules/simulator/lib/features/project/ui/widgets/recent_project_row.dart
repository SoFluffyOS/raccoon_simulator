import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/design/design.dart';

/// One recently opened folder: its name and path; tap opens it, × forgets it.
class RecentProjectRow extends StatefulWidget {
  const RecentProjectRow({
    super.key,
    required this.directory,
    required this.current,
    this.onOpen,
    this.onForget,
  });

  final String directory;

  /// Whether this is the open project.
  final bool current;

  final VoidCallback? onOpen;
  final VoidCallback? onForget;

  @override
  State<RecentProjectRow> createState() => _RecentProjectRowState();
}

class _RecentProjectRowState extends State<RecentProjectRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = switch ((widget.current, _hovered)) {
      (true, _) => Palette.surfaceRaised,
      (false, true) => Palette.hover,
      (false, false) => const Color(0x00000000),
    };
    return MouseRegion(
      cursor: switch (widget.onOpen) {
        null => SystemMouseCursors.basic,
        _ => SystemMouseCursors.click,
      },
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.d8,
            vertical: Spacing.d6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(Spacing.d6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(widget.directory),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typography.body.copyWith(
                        fontWeight: switch (widget.current) {
                          true => FontWeight.w600,
                          false => FontWeight.w400,
                        },
                      ),
                    ),
                    Text(
                      widget.directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typography.caption,
                    ),
                  ],
                ),
              ),
              if (_hovered && widget.onForget != null)
                GestureDetector(
                  onTap: widget.onForget,
                  child: const Padding(
                    padding: EdgeInsets.all(Spacing.d4),
                    child: Text('×', style: Typography.title),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
