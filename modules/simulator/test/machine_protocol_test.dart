import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator/features/run/run.dart';

void main() {
  group('MachineProtocol.parse', () {
    test('reads daemon.connected', () {
      final message = MachineProtocol.parse(
        '[{"event":"daemon.connected","params":{"version":"0.6.1","pid":77}}]',
      );
      expect(message, isA<DaemonConnected>());
      final connected = message as DaemonConnected;
      expect(connected.version, '0.6.1');
      expect(connected.pid, 77);
    });

    test('reads app.start with its restart support', () {
      final message = MachineProtocol.parse(
        '[{"event":"app.start","params":{"appId":"a1","deviceId":"raccoon",'
        '"directory":"/work/hello","supportsRestart":true,"launchMode":"run",'
        '"mode":"debug"}}]',
      );
      expect(message, isA<AppStart>());
      final start = message as AppStart;
      expect(start.appId, 'a1');
      expect(start.deviceId, 'raccoon');
      expect(start.directory, '/work/hello');
      expect(start.supportsRestart, isTrue);
      expect(start.mode, 'debug');
    });

    test('reads app.progress, started and finished', () {
      final started = MachineProtocol.parse(
        '[{"event":"app.progress","params":{"appId":"a1","id":"0",'
        '"progressId":null,"message":"Launching lib/main.dart on Raccoon in '
        'debug mode...","finished":false}}]',
      );
      expect(started, isA<AppProgress>());
      expect((started as AppProgress).message, startsWith('Launching'));
      expect(started.finished, isFalse);
      expect(started.progressId, '0');

      final finished = MachineProtocol.parse(
        '[{"event":"app.progress","params":{"appId":"a1","id":"1",'
        '"progressId":"hot.reload","finished":true}}]',
      );
      expect((finished as AppProgress).finished, isTrue);
      expect(finished.progressId, 'hot.reload');
      expect(finished.message, isNull);
    });

    test('reads app.debugPort, app.started, app.log and app.stop', () {
      final port = MachineProtocol.parse(
        '[{"event":"app.debugPort","params":{"appId":"a1","port":41000,'
        '"wsUri":"ws://127.0.0.1:41000/abc=/ws","baseUri":"file:///x/"}}]',
      );
      expect((port as AppDebugPort).wsUri, 'ws://127.0.0.1:41000/abc=/ws');

      final started = MachineProtocol.parse(
        '[{"event":"app.started","params":{"appId":"a1"}}]',
      );
      expect((started as AppStarted).appId, 'a1');

      final log = MachineProtocol.parse(
        '[{"event":"app.log","params":{"appId":"a1","log":"boom","error":true}}]',
      );
      expect((log as AppLog).log, 'boom');
      expect(log.isError, isTrue);

      final stop = MachineProtocol.parse(
        '[{"event":"app.stop","params":{"appId":"a1","error":"crashed"}}]',
      );
      expect((stop as AppStop).error, 'crashed');
    });

    test('reads daemon log messages, errors flagged', () {
      final info = MachineProtocol.parse(
        '[{"event":"daemon.logMessage","params":{"level":"status",'
        '"message":"Syncing files"}}]',
      );
      expect((info as DaemonLog).message, 'Syncing files');
      expect(info.isError, isFalse);

      final error = MachineProtocol.parse(
        '[{"event":"daemon.logMessage","params":{"level":"error",'
        '"message":"No device"}}]',
      );
      expect((error as DaemonLog).isError, isTrue);
    });

    test('keeps unknown events', () {
      final message = MachineProtocol.parse(
        '[{"event":"app.webLaunchUrl","params":{"url":"http://x"}}]',
      );
      expect(message, isA<OtherEvent>());
      expect((message as OtherEvent).event, 'app.webLaunchUrl');
    });

    test('reads responses to app.restart', () {
      final ok = MachineProtocol.parse(
        '[{"id":1,"result":{"code":0,"message":""}}]',
      );
      expect((ok as MachineResponse).id, 1);
      expect(ok.succeeded, isTrue);
      expect(ok.failure, isNull);

      final rejected = MachineProtocol.parse(
        '[{"id":2,"result":{"code":1,"message":"Reload rejected"}}]',
      );
      expect((rejected as MachineResponse).succeeded, isFalse);
      expect(rejected.failure, 'Reload rejected');

      final error = MachineProtocol.parse('[{"id":3,"error":"no app"}]');
      expect((error as MachineResponse).failure, 'no app');

      final plain = MachineProtocol.parse('[{"id":4,"result":true}]');
      expect((plain as MachineResponse).succeeded, isTrue);
    });

    test('treats app print output and other text as plain lines', () {
      for (final line in [
        'flutter: tapped',
        'tapped',
        '',
        '[not json',
        '[{"oops": }]',
        '[{"neither":"event nor id"}]',
        '{"event":"app.started"}',
      ]) {
        final message = MachineProtocol.parse(line);
        expect(message, isA<PlainOutput>(), reason: line);
        expect((message as PlainOutput).text, line);
      }
    });
  });

  test('encodeRequest writes one array holding the command', () {
    final line = MachineProtocol.encodeRequest(7, 'app.restart', {
      'appId': 'a1',
      'fullRestart': true,
    });
    expect(jsonDecode(line), [
      {
        'id': 7,
        'method': 'app.restart',
        'params': {'appId': 'a1', 'fullRestart': true},
      },
    ]);
  });
}
