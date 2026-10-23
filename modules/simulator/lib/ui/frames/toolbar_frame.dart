import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:simulator/app/simulator_controller.dart';
import 'package:simulator/design/design.dart';
import 'package:simulator/features/features.dart';
import 'package:simulator/services/services.dart';
import 'package:simulator/ui/dialogs/dialogs.dart';
import 'package:simulator/ui/widgets/widgets.dart';
import 'package:simulator/utils/utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The top bar: the shown app and its state, then compact icon buttons for
/// Run or Stop, hot reload, hot restart, the size presets and settings.
///
/// Run and the reloads are for runs started here. An app run from an editor
/// reloads from the editor, so they only appear with a project open.
class ToolbarFrame extends StatelessWidget {
  const ToolbarFrame({super.key});

  static const runKey = ValueKey('toolbar-run');
  static const stopKey = ValueKey('toolbar-stop');
  static const reloadKey = ValueKey('toolbar-reload');
  static const restartKey = ValueKey('toolbar-restart');
  static const settingsKey = ValueKey('toolbar-settings');
  static const boardKey = ValueKey('toolbar-board');

  @override
  Widget build(BuildContext context) {
    final runName = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.appName,
    );
    final projectName = context.select<ProjectViewModel, String?>(
      (viewModel) => viewModel.project?.appName,
    );
    final shownName = context.select<SessionService, String?>(
      (service) => service.shownApp(running: runName, project: projectName),
    );
    final connected = context.select<SessionService, bool>(
      (service) => switch (shownName) {
        final name? => service.session(name) != null,
        null => false,
      },
    );
    final phase = context.select<RunViewModel, RunPhase>(
      (viewModel) => viewModel.phase,
    );
    final progress = context.select<RunViewModel, String?>(
      (viewModel) => viewModel.progress,
    );
    final launch = context.select<RunViewModel, Duration?>(
      (viewModel) => viewModel.launchTime,
    );
    final restart = context.select<RunViewModel, RestartResult?>(
      (viewModel) => viewModel.lastRestart,
    );
    final canRestart = context.select<RunViewModel, bool>(
      (viewModel) => viewModel.canRestart,
    );
    final settingUp = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.settingUp,
    );
    final needsSetup = context.select<RuntimeViewModel, bool>(
      (viewModel) => viewModel.needsSetup,
    );
    context
      ..select<RuntimeViewModel, bool>((viewModel) => viewModel.isReady)
      ..select<RuntimeViewModel, FlutterSdk?>((viewModel) => viewModel.sdk);
    final leadingInset = context.select<WindowChrome, double>(
      (chrome) => chrome.leadingInset,
    );
    final controller = context.read<SimulatorController>();
    final run = context.read<RunViewModel>();
    final blocker = controller.runBlocker;
    final typography = context.fluffyTheme.typography;
    final (color, state) = switch (phase) {
      RunPhase.idle => switch ((connected, settingUp, needsSetup)) {
        (true, _, _) => (Palette.ok, 'On Raccoon'),
        (false, true, _) => (Palette.warning, 'Setting up'),
        (false, false, true) => (Palette.error, 'Needs setup'),
        (false, false, false) => (
          Palette.textFaint,
          'Waiting for flutter run -d raccoon',
        ),
      },
      RunPhase.starting => (Palette.warning, progress ?? 'Starting'),
      RunPhase.running => (Palette.ok, _runningLabel(launch, restart)),
      RunPhase.stopping => (Palette.warning, 'Stopping'),
    };
    final showRunControls = projectName != null || phase != RunPhase.idle;
    return Container(
      height: Spacing.d36,
      padding: EdgeInsets.only(
        left: Spacing.d8 + leadingInset,
        right: Spacing.d8,
      ),
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(bottom: BorderSide(color: Palette.border)),
      ),
      child: Row(
        children: [
          Spacing.h4,
          StatusDot(color: color),
          Spacing.h8,
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    shownName ?? 'Raccoon Simulator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.base2.copyWith(
                      color: Palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacing.h8,
                Flexible(
                  child: Text(
                    state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption2.copyWith(
                      color: Palette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Spacing.h8,
          if (showRunControls) ...[
            switch (phase) {
              RunPhase.idle => IconToolButton(
                key: runKey,
                icon: LucideIcons.play,
                tooltip: blocker ?? 'Run $projectName',
                color: Palette.ok,
                onTap: switch (blocker) {
                  null => controller.start,
                  _ => null,
                },
              ),
              RunPhase.starting || RunPhase.running => IconToolButton(
                key: stopKey,
                icon: LucideIcons.square,
                tooltip: 'Stop',
                color: Palette.error,
                onTap: controller.stop,
              ),
              RunPhase.stopping => const IconToolButton(
                icon: LucideIcons.loaderCircle,
                tooltip: 'Stopping',
              ),
            },
            IconToolButton(
              key: reloadKey,
              icon: LucideIcons.zap,
              tooltip: RestartKind.hotReload.label,
              onTap: switch (canRestart) {
                true => () => run.restart(RestartKind.hotReload),
                false => null,
              },
            ),
            IconToolButton(
              key: restartKey,
              icon: LucideIcons.rotateCcw,
              tooltip: RestartKind.hotRestart.label,
              onTap: switch (canRestart) {
                true => () => run.restart(RestartKind.hotRestart),
                false => null,
              },
            ),
            const ToolbarSeparator(),
          ],
          const PresetBarFrame(),
          const DevicesButtonFrame(),
          IconToolButton(
            key: boardKey,
            icon: LucideIcons.layoutDashboard,
            tooltip: 'Board: every running device on one canvas',
            selected: context.select<ViewerViewModel, bool>(
              (viewModel) => viewModel.boardOn,
            ),
            onTap: context.read<ViewerViewModel>().toggleBoard,
          ),
          const ToolbarSeparator(),
          IconToolButton(
            key: settingsKey,
            icon: LucideIcons.settings,
            tooltip: 'Settings',
            color: switch (needsSetup) {
              true => Palette.warning,
              false => null,
            },
            onTap: () => SettingsDialog.show(context),
          ),
        ],
      ),
    );
  }

  static String _runningLabel(Duration? launch, RestartResult? restart) {
    if (restart case final restart?) {
      final failed = switch (restart.succeeded) {
        true => '',
        false => ' failed',
      };
      return '${restart.kind.label} ${formatDuration(restart.duration)}$failed';
    }
    return switch (launch) {
      final launch? => 'Launched in ${formatDuration(launch)}',
      null => 'Running',
    };
  }
}
