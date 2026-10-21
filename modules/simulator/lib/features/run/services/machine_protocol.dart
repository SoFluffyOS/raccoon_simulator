import 'dart:convert';

import 'package:simulator/features/run/models/models.dart';

/// Reads and writes the protocol of `flutter run --machine`: one JSON array
/// with one object per line, events from the tool and commands to it.
abstract final class MachineProtocol {
  /// Decodes one line of the tool's stdout.
  static MachineMessage parse(String line) {
    final trimmed = line.trim();
    final looksLikeJson = trimmed.startsWith('[{') && trimmed.endsWith('}]');
    if (!looksLikeJson) return PlainOutput(line);
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return PlainOutput(line);
    }
    if (decoded case [final Map<String, Object?> object]) {
      return _fromObject(object) ?? PlainOutput(line);
    }
    return PlainOutput(line);
  }

  /// Encodes a command for the tool's stdin, without the line break.
  static String encodeRequest(
    int id,
    String method,
    Map<String, Object?> params,
  ) => jsonEncode([
    {'id': id, 'method': method, 'params': params},
  ]);

  static MachineMessage? _fromObject(Map<String, Object?> object) {
    if (object case {'event': final String event}) {
      final params = switch (object['params']) {
        final Map<String, Object?> map => map,
        _ => const <String, Object?>{},
      };
      return _event(event, params);
    }
    if (object case {'id': final int id}) {
      return MachineResponse(
        id: id,
        result: object['result'],
        error: object['error'],
      );
    }
    return null;
  }

  static MachineMessage _event(String event, Map<String, Object?> params) {
    final appId = params['appId'];
    switch ((event, appId)) {
      case ('daemon.connected', _):
        return DaemonConnected(
          version: '${params['version'] ?? ''}',
          pid: _int(params['pid']),
        );
      case ('daemon.logMessage', _):
        return DaemonLog(
          message: '${params['message'] ?? ''}',
          isError: params['level'] == 'error',
        );
      case ('daemon.log', _):
        return DaemonLog(
          message: '${params['log'] ?? ''}',
          isError: params['error'] == true,
        );
      case ('app.start', final String appId):
        return AppStart(
          appId: appId,
          deviceId: '${params['deviceId'] ?? ''}',
          directory: _string(params['directory']),
          supportsRestart: params['supportsRestart'] == true,
          mode: _string(params['mode']),
        );
      case ('app.debugPort', final String appId):
        if (params['wsUri'] case final String wsUri) {
          return AppDebugPort(appId: appId, wsUri: wsUri);
        }
      case ('app.started', final String appId):
        return AppStarted(appId: appId);
      case ('app.progress', final String appId):
        return AppProgress(
          appId: appId,
          progressId: '${params['progressId'] ?? params['id'] ?? ''}',
          message: _string(params['message']),
          finished: params['finished'] == true,
        );
      case ('app.log', final String appId):
        return AppLog(
          appId: appId,
          log: '${params['log'] ?? ''}',
          isError: params['error'] == true,
        );
      case ('app.stop', final String appId):
        return AppStop(appId: appId, error: _string(params['error']));
    }
    return OtherEvent(event: event, params: params);
  }

  static String? _string(Object? value) => switch (value) {
    final String text => text,
    _ => null,
  };

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    _ => null,
  };
}
