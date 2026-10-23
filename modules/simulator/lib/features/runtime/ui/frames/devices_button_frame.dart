import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/ui/frames/devices_menu_frame.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The toolbar's devices button: opens [DevicesMenuFrame] under it, closed
/// by a tap anywhere else or the button again.
class DevicesButtonFrame extends StatefulWidget {
  const DevicesButtonFrame({super.key});

  static const buttonKey = ValueKey('toolbar-devices');

  @override
  State<DevicesButtonFrame> createState() => _DevicesButtonFrameState();
}

class _DevicesButtonFrameState extends State<DevicesButtonFrame> {
  final _menu = OverlayPortalController();
  final _link = LayerLink();

  static const _group = 'simulator-devices-menu';

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _menu,
        overlayChildBuilder: (context) => Positioned(
          width: Spacing.d320,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: Offset(0, Spacing.d4),
            child: TapRegion(
              groupId: _group,
              onTapOutside: (_) => _menu.hide(),
              child: Container(
                padding: EdgeInsets.all(Spacing.d12),
                decoration: const BoxDecoration(
                  color: Palette.surface,
                  borderRadius: Spacing.r8,
                ),
                child: const DevicesMenuFrame(),
              ),
            ),
          ),
        ),
        child: TapRegion(
          groupId: _group,
          child: IconToolButton(
            key: DevicesButtonFrame.buttonKey,
            icon: LucideIcons.monitorSmartphone,
            tooltip: 'Devices',
            onTap: _menu.toggle,
          ),
        ),
      ),
    );
  }
}
