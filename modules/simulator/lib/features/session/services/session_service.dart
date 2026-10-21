import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';
import 'package:simulator/features/session/models/models.dart';
import 'package:simulator/utils/utils.dart';

/// Connects to a runner; [RunnerClient.connect] in the app.
typedef RunnerConnector = Future<RunnerClient> Function(
  UnixSocketEndpoint endpoint,
);

/// Follows the runners in one socket directory and keeps a client connected
/// to each.
///
/// Sessions are keyed by app name, and callers look the live one up by name
/// every time ([session]) instead of holding on to a [RunnerSession]: each
/// `flutter run` starts a new runner under the same name, and a view that
/// kept the old session would keep showing a closed client.
final class SessionService extends ChangeNotifier {
  SessionService({
    required RunnerConnector connect,
    void Function(RunnerClient client)? onConnected,
    this.helloTimeout = const Duration(seconds: 5),
    this.reconnectDelay = const Duration(milliseconds: 300),
  }) : _connect = connect,
       _onConnected = onConnected;

  final RunnerConnector _connect;
  final void Function(RunnerClient client)? _onConnected;

  /// How long to wait for the runner's hello. A runner that hangs up first
  /// is held by another client; one that stays silent is taken as connected.
  final Duration helloTimeout;

  /// How long to wait, after a session's runner hangs up, before looking for
  /// a new runner behind the same socket path.
  final Duration reconnectDelay;

  final _sessions = <String, RunnerSession>{};
  final _refused = <String>{};
  final _freshSince = <String, DateTime>{};
  Timer? _freshPoll;
  StreamSubscription<List<UnixSocketEndpoint>>? _watch;
  RunnerDiscovery? _discovery;
  var _endpoints = <UnixSocketEndpoint>[];
  Future<void> _work = Future.value();
  var _generation = 0;
  var _disposed = false;

  /// The directory being followed, once [follow] was called.
  String? get directory => _discovery?.directory;

  List<RunnerSession> get sessions => List.unmodifiable(_sessions.values);

  /// The live session for [name], or null while there is none.
  RunnerSession? session(String name) => _sessions[name];

  /// Whether the runner for [name] turned this client away because another
  /// client, such as an IDE, is connected to it.
  bool isRefused(String name) => _refused.contains(name);

  /// Follows the runners in [discovery]'s directory, dropping the sessions
  /// of any directory followed before.
  void follow(RunnerDiscovery discovery) {
    if (_discovery?.directory == discovery.directory) return;
    _generation++;
    unawaited(_watch?.cancel());
    _closeAll();
    _discovery = discovery;
    final generation = _generation;
    _watch = discovery.watch().listen(
      (endpoints) => _enqueue(() => _sync(endpoints, generation)),
      onError: (Object error, StackTrace stackTrace) =>
          printError('runner discovery failed: $error', stackTrace),
    );
    notifyListeners();
  }

  /// Tries again to connect to every runner present, for a runner that was
  /// refused while another client held it.
  Future<void> retry() {
    _refused.clear();
    notifyListeners();
    final generation = _generation;
    return _enqueue(() => _sync(_endpoints, generation));
  }

  /// Connects to [name]'s runner only through a socket created after
  /// [since], dropping the current session if it is older.
  ///
  /// A runner left over from an earlier run, or one whose tool died, keeps
  /// listening on an old socket until the new runner replaces it; without
  /// this the simulator could attach to the stale app. Call it as a run
  /// starts. Old sockets are checked again until a fresh one appears or
  /// [freshTimeout] passes.
  void expectFresh(String name, {required DateTime since}) {
    _freshSince[name] = since;
    _refused.remove(name);
    final generation = _generation;
    unawaited(
      _enqueue(() async {
        final session = _sessions[name];
        if (session != null && !_isFresh(session.endpoint, since)) {
          await _close(name);
        }
        await _sync(_discovery?.list() ?? _endpoints, generation);
      }),
    );
    _freshPoll ??= Timer.periodic(freshPollInterval, (_) => _pollFresh());
  }

  /// How often old sockets are looked at again, see [expectFresh].
  static const freshPollInterval = Duration(milliseconds: 250);

  /// How long [expectFresh] waits for a fresh socket.
  static const freshTimeout = Duration(minutes: 3);

  void _pollFresh() {
    final now = DateTime.now();
    _freshSince.removeWhere(
      (name, since) =>
          _sessions.containsKey(name) || now.difference(since) > freshTimeout,
    );
    if (_freshSince.isEmpty) {
      _freshPoll?.cancel();
      _freshPoll = null;
      return;
    }
    final generation = _generation;
    unawaited(
      _enqueue(() => _sync(_discovery?.list() ?? _endpoints, generation)),
    );
  }

  /// Whether [endpoint]'s socket file was made after [since], give or take
  /// the file system's timestamp resolution.
  static bool _isFresh(UnixSocketEndpoint endpoint, DateTime since) {
    final stat = FileStat.statSync(endpoint.path);
    if (stat.type == FileSystemEntityType.notFound) return false;
    final made = stat.changed;
    return !made.isBefore(since.subtract(const Duration(seconds: 1)));
  }

  /// Lets [follow]'s work settle; for tests.
  @visibleForTesting
  Future<void> get settled => _work;

  Future<void> _enqueue(Future<void> Function() task) =>
      _work = _work.then((_) => task());

  Future<void> _sync(List<UnixSocketEndpoint> endpoints, int generation) async {
    if (generation != _generation || _disposed) return;
    _endpoints = endpoints;
    final present = <String>{};
    for (final endpoint in endpoints) {
      final name = RunnerDiscovery.appNameOf(endpoint);
      present.add(name);
      final known = _sessions.containsKey(name) || _refused.contains(name);
      if (!known) await _open(name, endpoint, generation);
    }
    final gone = [
      for (final name in _sessions.keys)
        if (!present.contains(name)) name,
    ];
    for (final name in gone) {
      await _close(name);
    }
    final refusedGone = _refused.difference(present);
    if (refusedGone.isEmpty) return;
    _refused.removeAll(refusedGone);
    _notify();
  }

  Future<void> _open(
    String name,
    UnixSocketEndpoint endpoint,
    int generation,
  ) async {
    if (_freshSince[name] case final since? when !_isFresh(endpoint, since)) {
      return;
    }
    final RunnerClient client;
    try {
      client = await _connect(endpoint);
    } on SocketException catch (error) {
      printLog('no runner behind ${endpoint.path}: ${error.message}');
      return;
    }
    final saidHello = await Future.any([
      client.hello.then((_) => true),
      client.closed.then((_) => false),
    ]).timeout(helloTimeout, onTimeout: () => true);
    if (generation != _generation || _disposed) {
      await client.close();
      return;
    }
    if (!saidHello) {
      printLog('runner $name refused the connection; another client has it');
      _refused.add(name);
      await client.close();
      _notify();
      return;
    }
    _onConnected?.call(client);
    final session = RunnerSession(
      name: name,
      endpoint: endpoint,
      client: client,
    );
    _sessions[name] = session;
    printLog('connected to $name at ${endpoint.path}');
    unawaited(client.closed.then((_) => _onClientClosed(session, generation)));
    _notify();
  }

  void _onClientClosed(RunnerSession session, int generation) {
    if (!identical(_sessions[session.name], session)) return;
    _sessions.remove(session.name);
    _notify();
    unawaited(
      Future<void>.delayed(reconnectDelay).then(
        (_) => _enqueue(() async {
          if (generation != _generation || _disposed) return;
          await _sync(_discovery?.list() ?? const [], generation);
        }),
      ),
    );
  }

  Future<void> _close(String name) async {
    final session = _sessions.remove(name);
    if (session == null) return;
    await session.client.close();
    _notify();
  }

  void _closeAll() {
    for (final session in _sessions.values) {
      unawaited(session.client.close());
    }
    _sessions.clear();
    _refused.clear();
    _freshSince.clear();
    _freshPoll?.cancel();
    _freshPoll = null;
    _endpoints = [];
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_watch?.cancel());
    _closeAll();
    super.dispose();
  }
}
