# Raccoon Simulator

![Platform](https://img.shields.io/badge/platform-macos%20%7C%20linux-lightgrey) [![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE) [![Powered by SoFluffy](https://img.shields.io/badge/Powered%20by-SoFluffy-orange)](https://sofluffy.io)

Run your Flutter app on Raccoon from the editor you already love, and see it in a window.

Open Raccoon Simulator, and Raccoon shows up in `flutter devices`. Pick it in VS Code, Android Studio, [Lumide](https://lumide.dev) or a terminal, then run as usual. Your app appears in the simulator. No project to open, no new workflow.

> [!WARNING]
> **Alpha.** Raccoon Simulator is in rapid development for [Lumide](https://lumide.dev). Expect changes.

## Highlights

- **Your editor, your workflow**: run, hot reload, hot restart and debug from your editor. The simulator just shows the app.
- **Set up on launch**: the first launch builds the runner, installs the engine and registers the Raccoon custom device for you.
- **A simulator window**: a compact toolbar over your app. Everything else lives in Settings.
- **Device sizes**: Fit, Phone, Tablet and Desktop presets that scale down to fit.
- **macOS and Linux**.

## Quick Start

```sh
git clone --recurse-submodules https://github.com/simonpham/raccoon_simulator.git
cd raccoon_simulator
./get.sh
cd apps/raccoon_simulator
flutter run -d macos   # or -d linux
```

The first launch takes a few minutes while it builds the runner. Then:

```sh
flutter devices                # lists Raccoon
cd my_app
flutter run -d raccoon         # or pick Raccoon in your editor
```

## Requirements

- Flutter 3.47+
- A C++17 compiler, CMake, Ninja, `curl` and `unzip` to build the runner
- macOS: `xcode-select --install` and `brew install cmake ninja`

## Run from the simulator

You can also skip the editor. Open **Settings**, pick a Flutter project under **Run from the simulator**, then use **Run**, **Hot reload** and **Hot restart** in the toolbar.

| Option | What it does |
|---|---|
| `[project folder]` | Opens a project at launch |
| `--run` | Runs it once the runtime is ready |
| `--no-setup` | Skips the setup at launch |
| `FLUTTER_ROOT` | Picks the Flutter SDK (otherwise `flutter` on the `PATH`, then FVM's default) |
| `RACCOON_SIMULATOR_ROOT` | Points at this checkout when the app runs from somewhere else |

## Good to know

- **One client per runner**: if another tool connects to your app's runner first, the simulator says so. Close it there and press Retry.
- **Plugins**: pure Dart ones, the clipboard and `url_launcher` work. No text input yet.
- **Shared config**: the Raccoon device lives in Flutter's global `~/.config/flutter/custom_devices.json`. Setup leaves an entry from another checkout alone.
- **Logs**: Settings copies the tool's and your app's output, for a bug report.
- **Rendering**: frames are software rendered and copied, as everywhere in Raccoon today.

## Contributing

Ideas and contributions are welcome. Before you start on a pull request, open an [issue](https://github.com/simonpham/raccoon_simulator/issues) or a [discussion](https://github.com/simonpham/raccoon_simulator/discussions), or say hi on the [SoFluffy Discord](https://discord.gg/VP6p5JQdgt). Things move fast, so let's agree on the plan first.

```sh
./run_tests.sh                 # analyze, unit and widget tests
./e2e.sh [project] [shots]     # real runtime and window, needs a display
```

Read [RULES.md](RULES.md) for how we write code here, and add yourself to [AUTHORS](AUTHORS) with your first change.

## License

Raccoon Simulator is released under the [BSD 3-Clause License](LICENSE), the same license as Flutter. So are the Raccoon packages it builds on, under `packages/`, `pub_packages/` and `native/`.
