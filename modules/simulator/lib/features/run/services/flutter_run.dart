import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simulator/features/run/models/models.dart';
import 'package:simulator/features/run/services/machine_protocol.dart';

/// Starts a process; [Process.start] in the app, a fake in tests.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

/// One `flutter run --machine` process: its decoded output, and commands
/// sent to it with their responses.
final class FlutterRun {
  FlutterRun(this._process) {
    _stdout = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onDone: _onOutputDone);
    _stderr = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _errors.add,
          onDone: () {
            _stderrDone.complete();
            unawaited(_errors.close());
          },
        );
    unawaited(_process.stdin.done.then<void>((_) {}, onError: (Object _) {}));
    unawaited(_process.exitCode.then(_onExit));
  }

  static Future<FlutterRun> start(
    FlutterRunRequest request, {
    ProcessStarter starter = Process.start,
  }) async {
    final process = await starter(
      request.flutter,
      request.arguments,
      workingDirectory: request.directory,
      environment: request.environment,
    );
    return FlutterRun(process);
  }

  final Process _process;
  late final StreamSubscription<String> _stdout;
  late final StreamSubscription<String> _stderr;
  final _messages = StreamController<MachineMessage>();
  final _errors = StreamController<String>();
  final _pending = <int, Completer<MachineResponse>>{};
  final _stdoutDone = Completer<void>();
  final _stderrDone = Completer<void>();
  var _nextId = 1;
  var _exited = false;

  /// Everything the tool writes to stdout, decoded; buffered until listened
  /// to, and closed when the process's output ends.
  Stream<MachineMessage> get messages => _messages.stream;

  /// The tool's stderr, line by line.
  Stream<String> get errors => _errors.stream;

  /// The tool's exit code, once its output is read too: the process can
  /// exit before the last lines, such as why a build failed, are. A runner
  /// the tool started can hold the pipes open, so that wait is short.
  late final Future<int> exitCode = _process.exitCode.then((code) async {
    await Future.wait([
      _stdoutDone.future,
      _stderrDone.future,
    ]).timeout(outputGrace, onTimeout: () => const []);
    return code;
  });

  /// How long [exitCode] waits for output after the process exited.
  static const outputGrace = Duration(seconds: 1);

  int get pid => _process.pid;

  /// Sends [method] and waits for its response. Completes with an error
  /// response when the process exits first.
  Future<MachineResponse> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    final id = _nextId++;
    if (_exited) {
      return Future.value(
        MachineResponse(id: id, error: 'flutter run has exited'),
      );
    }
    final completer = Completer<MachineResponse>();
    _pending[id] = completer;
    _process.stdin.writeln(MachineProtocol.encodeRequest(id, method, params));
    return completer.future;
  }

  /// Ends the process without asking the app to stop first.
  bool kill() => _process.kill();

  void _onLine(String line) {
    final message = MachineProtocol.parse(line);
    if (message case MachineResponse(:final id)) {
      _pending.remove(id)?.complete(message);
    }
    _messages.add(message);
  }

  void _onOutputDone() {
    _stdoutDone.complete();
    unawaited(_messages.close());
  }

  void _onExit(int code) {
    _exited = true;
    for (final MapEntry(key: id, value: completer) in _pending.entries) {
      completer.complete(
        MachineResponse(id: id, error: 'flutter run exited with code $code'),
      );
    }
    _pending.clear();
    unawaited(
      _process.stdin.close().then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Stops listening; the process itself is left to [kill] or its own exit.
  Future<void> dispose() async {
    await _stdout.cancel();
    await _stderr.cancel();
  }
}
