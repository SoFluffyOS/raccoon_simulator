import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/services/services.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

void main() {
  test('macOS leaves room for the window buttons, except in full screen', () {
    final chrome = WindowChrome(toolbarIsTitleBar: true);
    addTearDown(chrome.dispose);
    var notified = 0;
    chrome.addListener(() => notified++);

    expect(chrome.leadingInset, Spacing.d68);

    chrome.setFullScreen(true);
    expect(chrome.leadingInset, 0);

    chrome
      ..setFullScreen(true)
      ..setFullScreen(false);
    expect(chrome.leadingInset, Spacing.d68);
    expect(notified, 2);
  });

  test('a native title bar needs no room', () {
    final chrome = WindowChrome(toolbarIsTitleBar: false);
    addTearDown(chrome.dispose);

    expect(chrome.leadingInset, 0);
  });
}
