/// What the command line asked for:
/// `raccoon_simulator [project] [--run] [--no-setup]`.
final class SimulatorOptions {
  const SimulatorOptions({this.project, this.run = false, this.setUp = true});

  factory SimulatorOptions.parse(List<String> arguments) {
    String? project;
    var run = false;
    var setUp = true;
    for (final argument in arguments) {
      switch (argument) {
        case '--run':
          run = true;
        case '--no-setup':
          setUp = false;
        case final path when !path.startsWith('-'):
          project = path;
      }
    }
    return SimulatorOptions(project: project, run: run, setUp: setUp);
  }

  /// A project folder to open at launch.
  final String? project;

  /// Whether to run it as soon as the runtime is ready.
  final bool run;

  /// Whether to apply the runtime's missing fixes at launch, see
  /// `RuntimeViewModel.setUp`.
  final bool setUp;
}
