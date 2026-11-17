import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon/raccoon.dart';
import 'package:simulator/features/features.dart' hide LogLine;

void main() {
  test('the command to install is read as each distro says it', () {
    Plugins failed(String install) => Plugins(
      plugins: [
        PluginReport(
          name: 'camera_desktop',
          state: PluginState.PLUGIN_STATE_FAILED,
          detail:
              'did not build: needs the development files of '
              'gstreamer-app-1.0, as flutter run -d linux does: $install; '
              'see /tmp/build.log',
        ),
      ],
    );
    expect(
      failed('sudo apt install libgstreamer-plugins-base1.0-dev').install,
      'sudo apt install libgstreamer-plugins-base1.0-dev',
    );
    expect(
      failed("sudo dnf install 'pkgconfig(gstreamer-app-1.0)'").install,
      "sudo dnf install 'pkgconfig(gstreamer-app-1.0)'",
    );
    expect(
      failed(
        'sudo pacman -S gst-plugins-base and the package that provides '
        'pkgconfig(raccoon-missing-1)',
      ).install,
      'sudo pacman -S gst-plugins-base',
    );
    expect(
      failed(
        'sudo apt install libgstreamer-plugins-base1.0-dev '
        '(apt has none for webkit2gtk-4.0)',
      ).install,
      'sudo apt install libgstreamer-plugins-base1.0-dev',
    );
    expect(
      failed('the package that provides pkgconfig(raccoon-missing-1)').install,
      isNull,
    );
  });

  test('a plugin that loaded, or has no host, names nothing to install', () {
    expect(
      Plugins(
        plugins: [
          PluginReport(
            name: 'yaru_window_linux',
            state: PluginState.PLUGIN_STATE_NO_HOST,
            detail:
                "no implementation on Raccoon: it wants the view's GTK "
                'window, and there is no view yet (#365)',
          ),
          PluginReport(
            name: 'url_launcher_linux',
            state: PluginState.PLUGIN_STATE_LOADED,
          ),
        ],
      ).install,
      isNull,
    );
  });
}
