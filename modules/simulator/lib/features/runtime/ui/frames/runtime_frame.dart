import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/run/view_models/view_models.dart';
import 'package:simulator/features/runtime/models/models.dart';
import 'package:simulator/features/runtime/ui/widgets/widgets.dart';
import 'package:simulator/features/runtime/view_models/view_models.dart';
import 'package:simulator/ui/widgets/widgets.dart';

/// The sidebar's runtime block: setup, each check with its fix, and where
/// run sockets go.
class RuntimeFrame extends StatelessWidget {
  const RuntimeFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final checks = context.select<RuntimeViewModel, List<RuntimeCheck>>(
      (viewModel) => viewModel.checks,
    );
    final fixing = context.select<RuntimeViewModel, CheckKind?>(
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
    final busy = settingUp || fixing != null;
    return PanelSection(
      title: 'Runtime',
      actions: [
        if (!ready || settingUp)
          ToolButton(
            label: switch (settingUp) {
              true => 'Setting up…',
              false => 'Set up',
            },
            tone: ButtonTone.primary,
            onTap: switch (busy) {
              true => null,
              false => viewModel.setUp,
            },
          ),
        ToolButton(
          label: 'Re-check',
          onTap: switch (busy) {
            true => null,
            false => viewModel.refresh,
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.d8),
            child: Text(switch ((settingUp, ready)) {
              (true, _) =>
                'Setting up Raccoon. The first runner build takes a few '
                    'minutes; the log shows its progress.',
              (false, true) => 'Raccoon is listed in flutter devices.',
              (false, false) =>
                'Set up adds Raccoon to flutter devices: it builds the '
                    'runner and registers the custom device.',
            }, style: Typography.caption),
          ),
          for (final check in checks)
            CheckRow(
              key: ValueKey(check.kind),
              check: check,
              fixing: fixing == check.kind,
              onFix: switch (busy) {
                true => null,
                false => () => viewModel.fix(check.kind),
              },
            ),
          if (fixError case final error?)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.d4),
              child: Text(
                error,
                style: Typography.caption.copyWith(color: Palette.error),
              ),
            ),
          const SizedBox(height: Spacing.d12),
          ToggleSwitch(
            value: private,
            label: 'Private runner sockets',
            onChanged: switch (running) {
              true => null,
              false => viewModel.setPrivateSockets,
            },
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: Spacing.toggleIndent,
              top: Spacing.d2,
            ),
            child: Text(
              switch (private) {
                true =>
                  'Other clients will not see runs. '
                      'Sockets: $directory',
                false =>
                  'Shared with other clients, which may connect first '
                      '(a runner takes one client). Sockets: $directory',
              },
              style: Typography.caption,
            ),
          ),
        ],
      ),
    );
  }
}
