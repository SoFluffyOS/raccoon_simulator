import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/runtime/runtime.dart';

void main() {
  test(
    'output that is not UTF-8 comes through instead of failing the step',
    () async {
      // vcvars' environment on Windows is in the console's code page; a
      // profile path like C:\\Users\\José failed every Build.
      final result = await const CommandRunner().run('printf', [
        r'caf\303\251\nJos\351\r\nend',
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, ['café', 'Jos\u{fffd}', 'end']);
    },
    testOn: '!windows',
  );
}
