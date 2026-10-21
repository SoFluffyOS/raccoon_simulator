import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs a setup command and hands each line of its output to a callback.
final class CommandRunner {
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
    Future<void> pump(Stream<List<int>> stream, {required bool keep}) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (keep) stdoutLines.add(line);
          onLine?.call(line);
        });
    await Future.wait([
      pump(process.stdout, keep: true),
      pump(process.stderr, keep: false),
    ]);
    return (exitCode: await process.exitCode, stdout: stdoutLines);
  }
}
