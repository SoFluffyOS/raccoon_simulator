import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/app/app.dart';

void main() {
  test('sets up at launch unless told not to', () {
    expect(SimulatorOptions.parse(const []).setUp, isTrue);
    expect(SimulatorOptions.parse(const ['--no-setup']).setUp, isFalse);
  });

  test('reads the project folder and --run', () {
    final options = SimulatorOptions.parse(const ['/apps/hello', '--run']);

    expect(options.project, '/apps/hello');
    expect(options.run, isTrue);
    expect(options.setUp, isTrue);
  });
}
