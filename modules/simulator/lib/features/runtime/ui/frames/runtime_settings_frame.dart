import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/ui/widgets/widgets.dart';
import 'package:simulator/features/runtime/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The settings' setup block: what setup does, each check with its fix, and
/// where the simulator's own runs put their sockets.
class RuntimeSettingsFrame extends StatelessWidget {
  const RuntimeSettingsFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final checks = context.select<RuntimeViewModel, List<RuntimeCheck>>(
      (viewModel) => viewModel.checks,
    );
    final fixing = context.select<RuntimeViewModel, FixKind?>(
      (viewModel) => viewModel.fixing,
    );
    final fixError = context.select<RuntimeViewModel, String?>(
      (viewModel) => viewModel.fixError,
    );
    final settingUp = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.settingUp,
    );
    final ready = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.isReady,
    );
    final private = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.privateSockets,
    );
    final directory = context.select<RuntimeViewModel, String>(
      (viewModel) => viewModel.sockets.directory,
    );
    final running = context.select<RunViewModel, bool>(
      (viewModel) => viewModel.isActive,
    );
    final viewModel = context.read<RuntimeViewModel>();
    final typography = context.fluffyTheme.typography;
    final caption = typography.caption2.copyWith(color: Palette.textMuted);
    final busy = settingUp || fixing != null;
    return SettingsSection(
      title: 'Setup',
      actions: [
        if (!ready || settingUp)
          Button(
            variant: ButtonVariant.primary,
            label: switch (settingUp) {
              true => 'Setting up…',
              false => 'Set up',
            },
            enable: !busy,
            onPressed: viewModel.setUp,
          ),
        Button(
          variant: ButtonVariant.ghost,
          label: 'Re-check',
          enable: !busy,
          onPressed: viewModel.refresh,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch ((settingUp, ready)) {
            (true, _) =>
              'Setting up Raccoon. The first runner build takes a few '
                  'minutes.',
            (false, true) => 'Raccoon is listed in flutter devices.',
            (false, false) =>
              'Set up adds Raccoon to flutter devices: it downloads the '
                  'runner (or builds it) and registers the custom device.',
          }, style: caption),
          Spacing.v8,
          for (final check in checks)
            CheckRow(
              key: ValueKey(check.kind),
              check: check,
              fixing: switch (fixing) {
                final fix? when fix.check == check.kind => fix,
                _ => null,
              },
              onFix: switch (busy) {
                true => null,
                false => viewModel.fix,
              },
            ),
          if (fixError case final error?) ...[
            Spacing.v4,
            Text(error, style: caption.copyWith(color: Palette.error)),
          ],
          Spacing.v12,
          Row(
            children: [
              DisableWidget(
                disabled: running,
                child: SwitchToggle(
                  value: private,
                  onChanged: viewModel.setPrivateSockets,
                ),
              ),
              Spacing.h12,
              Expanded(
                child: Text(
                  'Private runner sockets',
                  style: typography.base2,
                ),
              ),
            ],
          ),
          Spacing.v4,
          Text(switch (private) {
            true =>
              'Runs started here get their own socket folder, so other '
                  'clients cannot take them. Sockets: $directory',
            false =>
              'Runs started here share the usual folder, where another '
                  'client may connect first (a runner takes one client). '
                  'Sockets: $directory',
          }, style: caption),
        ],
      ),
    );
  }
}
