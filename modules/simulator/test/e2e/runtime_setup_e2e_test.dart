// Runs the runtime panel's real checks and fixes against this checkout and
// machine. Skipped unless RACCOON_E2E=1, as it builds the runner (minutes the
// first time) and downloads what is missing:
//
//   RACCOON_E2E=1 flutter test test/e2e/runtime_setup_e2e_test.dart
//
// It leaves the "raccoon" custom device alone when another checkout's helper
// is registered, the way the panel shows that as a warning, not a failure.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/runtime/runtime.dart';

void main() {
  final enabled = Platform.environment['RACCOON_E2E'] == '1';

  test(
    'every runtime check passes after its fix',
    () async {
      final host = HostInfo.current();
      final doctor = RuntimeDoctor(host: host);
      final fixer = RuntimeFixer(host: host);
      final sdk = HostLocator.flutterSdk(host);
      final checkout = HostLocator.checkout(host);
      expect(sdk, isNotNull, reason: 'no Flutter SDK');
      expect(checkout, isNotNull, reason: 'no checkout');

      for (final check in doctor.check(sdk: sdk, checkout: checkout)) {
        stdout.writeln(
          '${check.kind.label}: ${check.status.name} ${check.detail}',
        );
        if (check.passes || check.fixLabel == null) continue;
        await fixer.fix(
          check.kind,
          sdk: sdk,
          checkout: checkout,
          onLine: (line) => stdout.writeln('  $line'),
        );
      }

      final after = doctor.check(sdk: sdk, checkout: checkout);
      for (final check in after) {
        stdout.writeln(
          '${check.kind.label}: ${check.status.name} ${check.detail}',
        );
      }
      expect(after.where((check) => !check.passes), isEmpty);
    },
    skip: switch (enabled) {
      true => false,
      false => 'set RACCOON_E2E=1 to run',
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
