/// Where runs find the runner: a folder with the binary and
/// `tool/raccoon-device`, the custom device helper. The checkout's
/// `raccoon/native/raccoon_runner` keeps the binary under `build/`; the
/// simulator's
/// runtime directory, where a downloaded release unpacks, at its root.
final class RunnerPaths {
  const RunnerPaths({
    required this.directory,
    required this.binary,
    required this.deviceHelper,
  });

  final String directory;
  final String binary;

  /// The script the tool's `custom_devices.json` entry points at.
  final String deviceHelper;

  @override
  bool operator ==(Object other) =>
      other is RunnerPaths &&
      other.directory == directory &&
      other.binary == binary &&
      other.deviceHelper == deviceHelper;

  @override
  int get hashCode => Object.hash(directory, binary, deviceHelper);

  @override
  String toString() => binary;
}
