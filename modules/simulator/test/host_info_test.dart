import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/runtime/runtime.dart';

void main() {
  test('macOS gets the Homebrew folders after its own PATH', () {
    final environment = HostInfo.withToolPaths('macos', {
      'PATH': '/usr/bin:/bin',
      'HOME': '/Users/me',
    });

    expect(
      environment['PATH'],
      '/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin',
    );
    expect(environment['HOME'], '/Users/me');
  });

  test('a PATH that has them already stays as it is', () {
    final original = {'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin'};

    expect(HostInfo.withToolPaths('macos', original), same(original));
  });

  test('Linux keeps its PATH', () {
    final original = {'PATH': '/usr/bin'};

    expect(HostInfo.withToolPaths('linux', original), same(original));
  });

  test('an empty PATH gets just the folders', () {
    expect(
      HostInfo.withToolPaths('macos', const {})['PATH'],
      '/opt/homebrew/bin:/usr/local/bin',
    );
  });
}
