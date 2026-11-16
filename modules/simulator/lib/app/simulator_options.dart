/// What the command line asked for:
/// `raccoon_simulator [project] [--run] [--no-setup] [--no-control]`.
final class SimulatorOptions {
  const SimulatorOptions({
    this.project,
    this.run = false,
    this.setUp = true,
    this.control = true,
  });

  factory SimulatorOptions.parse(List<String> arguments) {
    String? project;
    var run = false;
    var setUp = true;
    var control = true;
    for (final argument in arguments) {
      switch (argument) {
        case '--run':
          run = true;
        case '--no-setup':
          setUp = false;
        case '--no-control':
          control = false;
        case final path when !path.startsWith('-'):
          project = path;
      }
    }
    return SimulatorOptions(
      project: project,
      run: run,
      setUp: setUp,
      control: control,
    );
  }

  /// A project folder to open at launch.
  final String? project;

  /// Whether to run it as soon as the runtime is ready.
  final bool run;

  /// Whether to apply the runtime's missing fixes at launch, see
  /// `RuntimeViewModel.setUp`.
  final bool setUp;

  /// Whether to serve the control endpoint agents drive the board through,
  /// see `SimulatorControlHost`.
  final bool control;
}
