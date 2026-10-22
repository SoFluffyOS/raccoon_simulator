import 'dart:io';

/// A runner version: the checkout's `raccoon/native/raccoon_runner/VERSION`, a
/// downloaded runner's `VERSION`, or a release tag, like `0.3.0`,
/// `0.3.0-pre.1`, `v0.3.1` or `runner-v0.3.1`. Versions with the same major and minor are
/// compatible, so a checkout pinned at `0.3.0-pre.1` takes any `0.3.x`
/// release.
final class RunnerVersion {
  const RunnerVersion._(this.text, this.major, this.minor);

  static final _pattern = RegExp(
    r'^(?:runner-)?v?(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.+-]*)?$',
  );
  static final _prefix = RegExp(r'^(?:runner-)?v');

  /// Parses [text], or returns null when it is not a semantic version.
  static RunnerVersion? parse(String text) {
    final trimmed = text.trim();
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;
    final major = int.tryParse(match[1] ?? '');
    final minor = int.tryParse(match[2] ?? '');
    if (major == null || minor == null) return null;
    return RunnerVersion._(trimmed.replaceFirst(_prefix, ''), major, minor);
  }

  /// The version in [file], or null when the file is missing or holds
  /// something else.
  static RunnerVersion? read(String file) {
    final versionFile = File(file);
    if (!versionFile.existsSync()) return null;
    return parse(versionFile.readAsStringSync());
  }

  /// The version without a leading `v` or `runner-v`.
  final String text;

  final int major;
  final int minor;

  /// `0.3.x`: the releases compatible with this version.
  String get series => '$major.$minor.x';

  bool isCompatibleWith(RunnerVersion other) =>
      major == other.major && minor == other.minor;

  @override
  bool operator ==(Object other) =>
      other is RunnerVersion && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}
