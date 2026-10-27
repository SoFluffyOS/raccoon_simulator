import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs a setup command and hands each line of its output to a callback.
/// Not final, so tests can stand in for it.
class CommandRunner {
  const CommandRunner();

  /// Runs [executable] and returns its exit code and stdout lines.
  Future<({int exitCode, List<String> stdout})> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    void Function(String line)? onLine,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    unawaited(process.stdin.close());
    final stdoutLines = <String>[];
    Future<void> pump(Stream<List<int>> stream, {required bool keep}) =>
        _lines(stream).forEach((line) {
          if (keep) stdoutLines.add(line);
          onLine?.call(line);
        });
    await Future.wait([
      pump(process.stdout, keep: true),
      pump(process.stderr, keep: false),
    ]);
    return (exitCode: await process.exitCode, stdout: stdoutLines);
  }

  /// [bytes] a line at a time, each UTF-8 or else the system's code page:
  /// on Windows a command's output (vcvars' environment, a localized
  /// compiler) is in the console's, and a profile path like
  /// C:\Users\José must come through as it is.
  static Stream<String> _lines(Stream<List<int>> bytes) async* {
    final pending = <int>[];
    await for (final chunk in bytes) {
      var start = 0;
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] != 0x0a) continue;
        pending.addAll(chunk.sublist(start, i));
        yield _decode(pending);
        pending.clear();
        start = i + 1;
      }
      pending.addAll(chunk.sublist(start));
    }
    if (pending.isNotEmpty) yield _decode(pending);
  }

  static String _decode(List<int> line) {
    final end = switch (line) {
      [..., 0x0d] => line.length - 1,
      _ => line.length,
    };
    final bytes = line.sublist(0, end);
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Elsewhere the system's is UTF-8 too: what isn't, shown as is.
      return switch (Platform.isWindows) {
        true => systemEncoding.decode(bytes),
        false => utf8.decode(bytes, allowMalformed: true),
      };
    }
  }
}
