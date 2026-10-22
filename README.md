# Raccoon Simulator

![Platform](https://img.shields.io/badge/platform-macos%20%7C%20linux-lightgrey) [![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE) [![Powered by SoFluffy](https://img.shields.io/badge/Powered%20by-SoFluffy-orange)](https://sofluffy.io)

Run your Flutter app on Raccoon from the editor you already love, and see it in a window.

Open Raccoon Simulator, and Raccoon shows up in `flutter devices`. Pick it in VS Code, Android Studio, [Lumide](https://lumide.dev) or a terminal, then run as usual. Your app appears in the simulator. No project to open, no new workflow.

> [!WARNING]
> **Alpha.** Raccoon Simulator is in rapid development for [Lumide](https://lumide.dev). Expect changes.

## Demo

[![Flutter Wonderous running inside Lumide on Raccoon: edit a color, save, and the app hot reloads in its pane](https://github.com/user-attachments/assets/1acb4513-ac41-4376-b351-6295ddc439cd)](https://github.com/user-attachments/assets/c7005e54-43fe-48a1-9c44-0e8c6e8c84f2)

Flutter Wonderous running inside [Lumide](https://lumide.dev) on Raccoon: pick Raccoon, press Run, click through the app, edit a color, save, and it hot reloads. [Watch the full demo](https://github.com/user-attachments/assets/c7005e54-43fe-48a1-9c44-0e8c6e8c84f2) (45 s).

## Highlights

- **Your editor, your workflow**: run, hot reload, hot restart and debug from your editor. The simulator just shows the app.
- **Set up on launch**: the first launch downloads the prebuilt runner (or builds it when no release fits your host), installs the engine and registers the Raccoon custom device for you.
- **A simulator window**: a compact toolbar over your app. Everything else lives in Settings.
- **Device sizes**: Fit, Phone, Tablet and Desktop presets that scale down to fit.
- **macOS and Linux**.

## Benchmarks

Time to first frame of [Flutter Wonderous](https://github.com/gskinnerTeam/flutter-wonderous-app), from `flutter run` to the first rasterized frame. Medians of repeated runs.

| Target | First build, downloads included | Clean build | Warm run |
|---|---|---|---|
| Android emulator | 308 s | 20.1 s | 5.5 s |
| Chrome | | 25.8 s | 24.8 s |
| Linux desktop | | 13.8 s | 4.5 s |
| **Raccoon on Linux** | **15.5 s** | **12.0 s** | **3.5 s** |
| macOS desktop | | 46.4 s | 17.7 s |
| **Raccoon on macOS** | | **15.0 s** | **7.5 s** |

- **7× faster than Chrome** on a warm run, **3× faster than a macOS build** from clean, and a **first run in 15 s instead of 5 minutes** against Android.
- Linux: AMD Ryzen 9 7945HX, Flutter 3.47.7; Android is an API 35 x86_64 emulator with KVM. macOS: Apple M1 Pro, Flutter 3.47.5. Wonderous at `747b945` with a one-line first-frame probe; for Android its Gradle, Android Gradle plugin and Kotlin versions were raised to Flutter 3.47's minimums.
- **Clean** runs `flutter clean` first. **Warm** doesn't. **First build** starts from an empty Gradle home for Android, so Gradle and every dependency download, and from an empty engine cache for Raccoon, so its 15 MB engine downloads; it depends on the network.
- Reproduce with `native/raccoon_runner/tool/bench/`: `wonderous.sh` prepares the project, `first_frame.py` compares your desktop device with Raccoon (`--devices` for others, `--warm` to skip `flutter clean`).

Raccoon speeds up the inner loop: write, save, see. It doesn't replace testing on a real device or in a browser.

## Quick Start

```sh
git clone --recurse-submodules https://github.com/SoFluffyOS/raccoon_simulator.git
cd raccoon_simulator
./get.sh
cd apps/raccoon_simulator
flutter run -d macos   # or -d linux
```

The first launch downloads the runner, or builds it when no release fits your host, which takes a few minutes. Then:

```sh
flutter devices                # lists Raccoon
cd my_app
flutter run -d raccoon         # or pick Raccoon in your editor
```

## Requirements

- Flutter 3.27 and up for the apps you run (tested with 3.27.4 and 3.47.7); native plugin loading is tested on 3.47
- To build the runner yourself, when no prebuilt release fits your host or you want your own build: a C++17 compiler, CMake, Ninja, `curl` and `unzip`
- macOS: `xcode-select --install` and `brew install cmake ninja`, for that build

## Prebuilt binaries

**Download** in Settings fetches the runner release that matches this checkout (the same major and minor as `native/raccoon_runner/VERSION`) from [raccoon_runner's releases](https://github.com/SoFluffyOS/raccoon_runner/releases) and unpacks it, binary and device helper, into `~/.local/share/raccoon_simulator/runner` (under `$XDG_DATA_HOME` when set). The Raccoon device then points at that helper. **Build** stays for when there is no release for your host or no network; setup tries Download first, and a build in `native/raccoon_runner/build` always wins over a download. The download carries no quarantine attribute on macOS; an archive you fetch with a browser needs `xattr -d com.apple.quarantine raccoon_runner` before it runs.

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

Ideas and contributions are welcome. Before you start on a pull request, open an [issue](https://github.com/SoFluffyOS/raccoon/issues) (one tracker for every Raccoon repository; issues are off here) or a [discussion](https://github.com/SoFluffyOS/raccoon_simulator/discussions), or say hi on the [SoFluffy Discord](https://discord.gg/VP6p5JQdgt). Things move fast, so let's agree on the plan first.

```sh
./run_tests.sh                 # analyze, unit and widget tests
./e2e.sh [project] [shots]     # real runtime and window, needs a display
```

Read [RULES.md](RULES.md) for how we write code here, and add yourself to [AUTHORS](AUTHORS) with your first change.

## License

Raccoon Simulator is released under the [BSD 3-Clause License](LICENSE), the same license as Flutter. So are the Raccoon packages it builds on, under `packages/`, `pub_packages/` and `native/`.
