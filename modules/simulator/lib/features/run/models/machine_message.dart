/// One line of `flutter run --machine` output, decoded.
///
/// The tool writes each event and response as a JSON array holding one
/// object. Anything else on stdout, such as the app's own `print` output on
/// current Flutter versions, is a [PlainOutput].
sealed class MachineMessage {
  const MachineMessage();
}

/// `daemon.connected`: the tool is ready for commands.
final class DaemonConnected extends MachineMessage {
  const DaemonConnected({required this.version, this.pid});

  final String version;
  final int? pid;
}

/// `daemon.logMessage` or `daemon.log`: a message from the tool itself.
final class DaemonLog extends MachineMessage {
  const DaemonLog({required this.message, this.isError = false});

  final String message;
  final bool isError;
}

/// `app.start`: the tool has an app id and is building and launching it.
final class AppStart extends MachineMessage {
  const AppStart({
    required this.appId,
    required this.deviceId,
    this.directory,
    this.supportsRestart = false,
    this.mode,
  });

  final String appId;
  final String deviceId;
  final String? directory;
  final bool supportsRestart;
  final String? mode;
}

/// `app.debugPort`: the app's VM service.
final class AppDebugPort extends MachineMessage {
  const AppDebugPort({required this.appId, required this.wsUri});

  final String appId;
  final String wsUri;
}

/// `app.started`: the app runs and the tool is attached.
final class AppStarted extends MachineMessage {
  const AppStarted({required this.appId});

  final String appId;
}

/// `app.progress`: a step such as building or a reload, started or finished.
final class AppProgress extends MachineMessage {
  const AppProgress({
    required this.appId,
    required this.progressId,
    this.message,
    this.finished = false,
  });

  final String appId;

  /// The progress's own id, which the finished event repeats.
  final String progressId;
  final String? message;
  final bool finished;
}

/// `app.log`: a line the app logged, as the tool relays it.
final class AppLog extends MachineMessage {
  const AppLog({required this.appId, required this.log, this.isError = false});

  final String appId;
  final String log;
  final bool isError;
}

/// `app.stop`: the app ended, with the reason when it failed.
final class AppStop extends MachineMessage {
  const AppStop({required this.appId, this.error});

  final String appId;
  final String? error;
}

/// Any other event, kept so it can still be logged.
final class OtherEvent extends MachineMessage {
  const OtherEvent({required this.event, required this.params});

  final String event;
  final Map<String, Object?> params;
}

/// The answer to a command this side sent, matched by [id].
final class MachineResponse extends MachineMessage {
  const MachineResponse({required this.id, this.result, this.error});

  final int id;
  final Object? result;
  final Object? error;

  /// Whether the command worked. `app.restart` answers `{code: 0}` on
  /// success and a non-zero code with a message when a reload failed.
  bool get succeeded {
    if (error != null) return false;
    return switch (result) {
      {'code': final int code} => code == 0,
      _ => true,
    };
  }

  /// What went wrong, when the command failed.
  String? get failure {
    if (error case final error?) return '$error';
    return switch (result) {
      {'code': final int code, 'message': final String message}
          when code != 0 =>
        message,
      {'code': final int code} when code != 0 => 'failed with code $code',
      _ => null,
    };
  }
}

/// A line that is not part of the protocol.
final class PlainOutput extends MachineMessage {
  const PlainOutput(this.text);

  final String text;
}
