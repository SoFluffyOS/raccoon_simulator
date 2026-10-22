import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/runtime/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The settings' devices block: `raccoon` is always there; a second run and
/// the sized presets go in and out of the editor's picker with a switch,
/// and any device of the user's own shows with one too.
class DeviceSettingsFrame extends StatelessWidget {
  const DeviceSettingsFrame({super.key});

  static ValueKey<String> switchKey(String id) => ValueKey('device-$id');

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
    return SettingsSection(
      title: 'Devices',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ids.contains('raccoon')
                ? 'raccoon is in the picker. Add the others as you need them; '
                      'each is its own runner.'
                : 'Set up first: the devices point at the runner.',
            style: caption,
          ),
          Spacing.v12,
          for (final device in [RaccoonDevice.second, ...RaccoonDevice.presets])
            _row(
              device,
              on: ids.contains(device.id),
              enabled: hasRunner,
              detail: device.sizeArgument ?? 'a second run at the window size',
              onChanged: (on) => viewModel.setDevice(device, on: on),
              title: typography.base2,
              caption: caption,
            ),
          for (final device in custom)
            _row(
              device,
              on: true,
              enabled: hasRunner,
              detail: device.sizeArgument ?? 'the window size',
              onChanged: (on) => viewModel.setDevice(device, on: on),
              title: typography.base2,
              caption: caption,
            ),
          Spacing.v8,
          Text(
            'Any other size, from a terminal: '
            'raccoon_device add <name> --size WxH@R',
            style: caption,
          ),
        ],
      ),
    );
  }

  Widget _row(
    RaccoonDevice device, {
    required bool on,
    required bool enabled,
    required String detail,
    required void Function(bool on) onChanged,
    required TextStyle title,
    required TextStyle caption,
  }) => Padding(
    padding: EdgeInsets.only(bottom: Spacing.d8),
    child: Row(
      children: [
        DisableWidget(
          disabled: !enabled,
          child: SwitchToggle(
            key: switchKey(device.id),
            value: on,
            onChanged: onChanged,
          ),
        ),
        Spacing.h12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${device.label} · ${device.id}', style: title),
              Text(detail, style: caption),
            ],
          ),
        ),
      ],
    ),
  );
}
