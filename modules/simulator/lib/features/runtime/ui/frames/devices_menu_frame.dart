import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/ui/widgets/widgets.dart';
import 'package:simulator/features/runtime/view_models/view_models.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The devices menu: `raccoon` is always in the editor's picker, and a run's
/// size is picked on its board frame. The rest go in only to run copies of
/// a project side by side, since the Flutter tool runs a project once per
/// device. Extras an older setup left can go in one tap.
class DevicesMenuFrame extends StatelessWidget {
  const DevicesMenuFrame({super.key});

  static ValueKey<String> switchKey(String id) => ValueKey('device-$id');
  static const keepOnlyKey = ValueKey('devices-keep-only-raccoon');

  @override
  Widget build(BuildContext context) {
    final ids = context.select<RuntimeViewModel, List<String>>(
      (viewModel) => viewModel.deviceIds,
    );
    final hasRunner = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.runner != null,
    );
    final custom = context.select<RuntimeViewModel, List<RaccoonDevice>>(
      (viewModel) => viewModel.customDevices,
    );
    final viewModel = context.read<RuntimeViewModel>();
    final typography = context.fluffyTheme.typography;
    final caption = typography.caption2.copyWith(color: Palette.textMuted);
    final extras = ids.where((id) => id != 'raccoon').length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Devices',
          style: typography.base2.copyWith(
            color: Palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacing.v4,
        Text(
          switch (ids.contains('raccoon')) {
            true =>
              'Raccoon is always in the picker. Pick a run\'s size from its '
                  'frame on the board; switch one on here only to run copies '
                  'side by side.',
            false => 'Set up first: the devices point at the runner.',
          },
          style: caption,
        ),
        Spacing.v12,
        if (extras > 0) ...[
          Tappable(
            key: keepOnlyKey,
            onTap: viewModel.keepOnlyRaccoon,
            child: Text(
              'Keep only Raccoon ($extras more in the picker)',
              style: typography.base2.copyWith(color: Palette.accent),
            ),
          ),
          Spacing.v12,
        ],
        for (final device in [RaccoonDevice.second, ...RaccoonDevice.presets])
          DeviceRow(
            key: switchKey(device.id),
            device: device,
            on: ids.contains(device.id),
            enabled: hasRunner,
            detail: device.sizeArgument ?? 'a second run of the same project',
            onChanged: (on) => viewModel.setDevice(device, on: on),
          ),
        for (final device in custom)
          DeviceRow(
            key: switchKey(device.id),
            device: device,
            on: true,
            enabled: hasRunner,
            detail: device.sizeArgument ?? 'a run of your own',
            onChanged: (on) => viewModel.setDevice(device, on: on),
          ),
        Text(
          'Any other size, from a terminal: '
          'raccoon_device add <name> --size WxH@R',
          style: caption,
        ),
      ],
    );
  }
}
