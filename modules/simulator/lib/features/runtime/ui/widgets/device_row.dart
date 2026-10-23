import 'package:flutter/widgets.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/design/design.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A Raccoon device with a switch: in the editor's device picker or not.
class DeviceRow extends StatelessWidget {
  const DeviceRow({
    super.key,
    required this.device,
    required this.on,
    required this.enabled,
    required this.detail,
    required this.onChanged,
  });

  final RaccoonDevice device;
  final bool on;
  final bool enabled;

  /// The size it starts at, or what it is for.
  final String detail;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = context.fluffyTheme.typography;
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.d8),
      child: Row(
        children: [
          DisableWidget(
            disabled: !enabled,
            child: SwitchToggle(value: on, onChanged: onChanged),
          ),
          Spacing.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.label} · ${device.id}',
                  style: typography.base2.copyWith(color: Palette.text),
                ),
                Text(
                  detail,
                  style: typography.caption2.copyWith(color: Palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
