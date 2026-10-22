# Rules

How we work in this repository. They apply to everyone: people and coding
agents alike. `AGENTS.md` points here.

## Project

Raccoon Simulator is a Flutter desktop app (Dart 3.13+, Flutter 3.47+) for
macOS and Linux. It sets up the Raccoon runtime so `flutter devices` lists
Raccoon, then shows any app run on that device, from an editor or a
terminal, in its window. It can also run a project itself with
`flutter run -d raccoon --machine`. It is alpha and moves fast for Lumide.
Keep the code host-neutral. It is a pub workspace.

## Commands

```bash
./get.sh                                   # flutter pub get (restores a file pub rewrites in raccoon_view)
./run_tests.sh                             # analyze, then unit and widget tests
./e2e.sh [project] [screenshots]           # real runtime and window, needs a display
cd apps/raccoon_simulator && flutter run -d macos   # or -d linux
cd modules/simulator && flutter test test/path/to_test.dart
dart format apps modules && flutter analyze   # never format the submodules
```

## Layout

| Directory | Purpose |
|-----------|---------|
| `apps/raccoon_simulator/` | Entry point (`main.dart`), macOS and Linux runners, end-to-end test |
| `modules/simulator/` | Features, window UI, design tokens, tests |
| `raccoon/` | The Raccoon family (protocol, runtime, view, runner), one submodule, read-only here |

`modules/simulator/lib/`:

- `features/<name>/` with `models/`, `services/`, `view_models/`, `ui/{frames,widgets}`:
  `project` (picker, recents), `runtime` (checks, fixes, setup at launch),
  `run` (machine protocol, `flutter run` process, log), `session` (runner
  discovery and clients, the app shown), `viewer` (size presets, viewport).
- `app/`: `SimulatorServices` wires everything, `SimulatorController` holds the
  actions that span features, `SimulatorApp` is the window.
- `ui/`: cross-feature frames (toolbar, viewer), the settings dialog, the
  page, shared dumb widgets. `design/`: `Palette`, `SimulatorTheme`.
- `services/`: settings, the window chrome, the macOS title bar setup.

## Code

- **Imports**: package imports only, through barrel files (`models/models.dart`,
  `ui/widgets/widgets.dart`). Each folder with several files has a barrel named
  after it.
- **Null safety**: never `!`. Use `if (x case final v?)` or promotion with an
  early return.
- **Control flow**: early returns, no `else`. `switch` expressions instead of
  `? :`.
- **Widgets**: `flutter/widgets.dart`, not material, and
  [sofluffy_ui](https://pub.dev/packages/sofluffy_ui) components (`Tappable`,
  `Button`, `SwitchToggle`, `ListItem`, `DialogCard`) with Lucide icons. One
  widget per file. Frames read view models with `context.select` (never
  `context.watch`); widgets get plain values and callbacks.
- **Window**: a compact toolbar of icon buttons over the app, like a device
  simulator. Anything more goes in the settings dialog, not a new panel.
- **Layout by size**: read the window's size class with `context.screenSize`
  (sofluffy_ui's `ScreenSize`), not raw widths.
- **State**: `ChangeNotifier` view models provided with
  `ChangeNotifierProvider.value`. Return the same list instance until it
  changes, so `select` does not rebuild for nothing.
- **Design tokens**: sofluffy_ui's `Spacing` and `context.fluffyTheme`
  typography, and `Palette`; no magic numbers or inline colours.
- **Logging**: `printLog` / `printError`, never `print`.
- **Sessions by name**: look the live session up with
  `SessionService.session(name)` on every build; never keep a `RunnerSession`
  or its client, because each run brings a new runner under the same name.
- **Processes**: tests inject a `FlutterRunStarter`, a `ProcessStarter` or a
  `CommandRunner`; nothing under `test/` starts the real tool except
  `test/e2e` and `integration_test`.
- **Dispose** every controller, subscription and timer.

## Constraints

- Never edit the submodules here. A change they need goes to that
  submodule's own repository first.
- The custom device config (`~/.config/flutter/custom_devices.json`) is global
  and other tools may share it. Only the Register fix writes it, and setup
  leaves an entry from another checkout alone.
- A runner takes one client. The simulator follows the usual socket folder,
  where editor runs land. Runs it starts itself default to a private socket
  folder so no other client takes them.

## Commits

Conventional commits (`feat(run): ...`, `fix(session): ...`, `chore: ...`,
`docs: ...`), one focused commit per change. No `Co-Authored-By` or other
trailers.

Before committing:

- `dart format apps modules`
- `flutter analyze` is clean
- `./run_tests.sh` passes
- no `!`, no `else`, barrels used
- tests cover the new behaviour
