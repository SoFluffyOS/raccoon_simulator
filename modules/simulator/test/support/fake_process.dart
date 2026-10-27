import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A [Process] whose output a test writes and whose input it reads.
final class FakeProcess implements Process {
  FakeProcess({this.pid = 4242}) {
    _stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_stdinLines.add);
  }

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _stdinController = StreamController<List<int>>();
  final _stdinLines = StreamController<String>.broadcast();
  final _exit = Completer<int>();
  late final IOSink _stdin = IOSink(_stdinController.sink);
  final written = <String>[];
  var killed = false;

  @override
  final int pid;

  /// Lines the code under test wrote to stdin.
  Stream<String> get stdinLines => _stdinLines.stream;

  /// Every stdin line decoded as a machine-protocol request.
  Future<Map<String, Object?>> nextRequest() async {
    final line = await stdinLines.first;
    written.add(line);
    final decoded = jsonDecode(line) as List<Object?>;
    return decoded.single as Map<String, Object?>;
  }

  void emit(String line) => _stdout.add(utf8.encode('$line\n'));

  /// [bytes] on stdout as they are, UTF-8 or not.
  void emitBytes(List<int> bytes) => _stdout.add(bytes);

  void emitError(String line) => _stderr.add(utf8.encode('$line\n'));

  void emitEvent(String event, Map<String, Object?> params) => emit(
    jsonEncode([
      {'event': event, 'params': params},
    ]),
  );

  void respond(int id, {Object? result, Object? error}) => emit(
    jsonEncode([
      {'id': id, 'result': ?result, 'error': ?error},
    ]),
  );

  /// Exits with [code] while its output is still open, as a real process
  /// can before its last lines are read; [closeOutput] ends that.
  void exitBeforeOutput(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  Future<void> closeOutput() async {
    await _stdout.close();
    await _stderr.close();
  }

  Future<void> exit(int code) async {
    await _stdout.close();
    await _stderr.close();
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    unawaited(exit(-15));
    return true;
  }
}
