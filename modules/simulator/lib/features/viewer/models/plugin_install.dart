import 'package:raccoon/raccoon.dart';

/// What the runner's plugin report says to install for the plugins that
/// did not build.
extension PluginInstall on Plugins {
  /// What to run for the packages the plugins that did not build went
  /// without, as the runner names it: `sudo apt install libjson-glib-dev`;
  /// null when it names none.
  String? get install {
    final commands = {
      for (final plugin in plugins)
        if (plugin.state == PluginState.PLUGIN_STATE_FAILED &&
            plugin.detail.startsWith('did not build'))
          for (final match in _install.allMatches(plugin.detail)) ?match[0],
    };
    if (commands.isEmpty) return null;
    return commands.join(' && ');
  }

  /// The runner's command in a plugin's detail, up to what it says next:
  /// `sudo apt install libjson-glib-dev; see ...`, `sudo dnf install
  /// 'pkgconfig(json-glib-1.0)'`, ` and the package that provides ...`.
  static final _install = RegExp(
    r'sudo (?:apt install|dnf install|pacman -S|zypper install) '
    r'[^;]+?(?= and | \(|;|$)',
  );
}
