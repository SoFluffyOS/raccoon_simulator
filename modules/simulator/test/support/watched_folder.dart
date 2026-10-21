import 'package:raccoon_runtime/raccoon_runtime.dart';

/// A discovery of [directory] that polls it, as the app does on macOS.
///
/// Without a poll interval it watches file system events, and macOS reports
/// none for a socket's creation, so a runner restarted under the same name
/// would only be found if the reconnect happened to win the race.
RunnerDiscovery watched(String directory) =>
    RunnerDiscovery(directory, pollInterval: const Duration(milliseconds: 50));
