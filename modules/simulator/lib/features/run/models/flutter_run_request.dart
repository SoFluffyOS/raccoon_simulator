/// What to start: `flutter run -d <device> --machine` in a project.
final class FlutterRunRequest {
  const FlutterRunRequest({
    required this.flutter,
    required this.directory,
    this.deviceId = 'raccoon',
    this.environment = const {},
  });

  /// The `flutter` executable.
  final String flutter;

  /// The project to run.
  final String directory;

  final String deviceId;

  /// Variables to set for the tool, on top of this process's environment.
  final Map<String, String> environment;

  List<String> get arguments => ['run', '-d', deviceId, '--machine'];
}
