import 'dart:async';
import 'dart:io';

import 'package:raccoon/raccoon.dart';
import 'package:raccoon_runtime/raccoon_runtime.dart';

/// A runner stand-in on a real Unix socket: says hello with its [pid], or,
/// with [refuse], hangs up at once the way a runner does when another client
/// holds it.
final class FakeRunner {
  FakeRunner._(this.path, this.pid, this._server, {required this.refuse}) {
    _server.listen(_accept);
  }

  static Future<FakeRunner> start(
    String path, {
    int pid = 1,
    bool refuse = false,
  }) async {
    final server = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    return FakeRunner._(path, pid, server, refuse: refuse);
  }

  final String path;
  final int pid;
  final bool refuse;
  final ServerSocket _server;
  final _clients = <Socket>[];
  var connections = 0;

  void _accept(Socket socket) {
    connections++;
    if (refuse) {
      socket.destroy();
      return;
    }
    _clients.add(socket);
    socket.listen(null, onError: (Object _) {}, cancelOnError: true);
    socket.add(
      MessageFraming.frame(
        RunnerMessage(
          hello: RunnerHello(
            protocolVersion: RaccoonProtocol.version,
            pid: pid,
          ),
        ).writeToBuffer(),
      ),
    );
  }

  /// Sends [message] to every client, as the runner would.
  void send(RunnerMessage message) {
    for (final client in _clients) {
      client.add(MessageFraming.frame(message.writeToBuffer()));
    }
  }

  /// Hangs up on its clients but keeps listening, like a runner replaced so
  /// quickly that its socket path never changes.
  void dropClients() {
    for (final client in _clients) {
      unawaited(client.close().then<void>((_) {}, onError: (Object _) {}));
    }
    _clients.clear();
  }

  /// Exits like a runner: closes its clients' connections and removes its
  /// socket.
  Future<void> stop() async {
    for (final client in _clients) {
      unawaited(client.close().then<void>((_) {}, onError: (Object _) {}));
    }
    _clients.clear();
    await _server.close();
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
