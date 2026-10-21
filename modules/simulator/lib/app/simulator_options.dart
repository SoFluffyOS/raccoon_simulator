/// What the command line asked for: `raccoon_simulator [project] [--run]`.
final class SimulatorOptions {
  const SimulatorOptions({this.project, this.run = false});

  factory SimulatorOptions.parse(List<String> arguments) {
    String? project;
    var run = false;
    for (final argument in arguments) {
      switch (argument) {
        case '--run':
          run = true;
        case final path when !path.startsWith('-'):
          project = path;
      }
    }
    return SimulatorOptions(project: project, run: run);
  }

  /// A project folder to open at launch.
  final String? project;

  /// Whether to run it as soon as the runtime is ready.
  final bool run;
}
