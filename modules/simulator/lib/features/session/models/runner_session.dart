import 'package:raccoon_runtime/raccoon_runtime.dart';

/// A connected runner, named after the app it hosts.
final class RunnerSession {
  const RunnerSession({
    required this.name,
    required this.endpoint,
    required this.client,
  });

  /// The app's pubspec name: the runner's socket is `<name>.sock`.
  final String name;
  final UnixSocketEndpoint endpoint;
  final RunnerClient client;

  int? get pid => client.pid;

  String? get vmServiceUri => client.vmServiceUri;
}
