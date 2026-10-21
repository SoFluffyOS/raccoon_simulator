import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/session/session.dart';

void main() {
  test('shared sockets use the host directory and change nothing', () {
    final sockets = RunnerSockets.forHost(
      operatingSystem: 'linux',
      environment: const {'XDG_RUNTIME_DIR': '/run/user/7'},
      temporaryDirectory: '/tmp',
      private: false,
    );
    expect(sockets.directory, '/run/user/7/raccoon');
    expect(sockets.environment, isEmpty);
    expect(sockets.isPrivate, isFalse);
  });

  test('private sockets on Linux move XDG_RUNTIME_DIR for the run', () {
    final sockets = RunnerSockets.forHost(
      operatingSystem: 'linux',
      environment: const {'XDG_RUNTIME_DIR': '/run/user/7'},
      temporaryDirectory: '/tmp',
      private: true,
    );
    expect(sockets.environment, {
      'XDG_RUNTIME_DIR': '/run/user/7/raccoon_simulator',
    });
    expect(sockets.directory, '/run/user/7/raccoon_simulator/raccoon');
  });

  test('private sockets on macOS move TMPDIR for the run', () {
    final sockets = RunnerSockets.forHost(
      operatingSystem: 'macos',
      environment: const {},
      temporaryDirectory: '/var/folders/xy/T',
      private: true,
    );
    expect(sockets.environment, {
      'TMPDIR': '/var/folders/xy/T/raccoon_simulator',
    });
    expect(sockets.directory, '/var/folders/xy/T/raccoon_simulator/raccoon');
  });
}
