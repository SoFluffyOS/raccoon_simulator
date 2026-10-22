import 'dart:io';

/// A runner version: the checkout's `raccoon/native/raccoon_runner/VERSION`, a
/// downloaded runner's `VERSION`, or a release tag, like `0.3.0`,
/// `0.3.0-pre.1`, `v0.3.1` or `runner-v0.3.1`. Versions with the same major and minor are
/// compatible, so a checkout pinned at `0.3.0-pre.1` takes any `0.3.x`
/// release; one older than the pin is still stale, see [isOlderThan].
final class RunnerVersion {
  const RunnerVersion._(
    this.text,
    this.major,
    this.minor,
    this.patch,
    this.prerelease,
  );

  static final _pattern = RegExp(
    r'^(?:runner-)?v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.+-]*)?$',
  );
  static final _prefix = RegExp(r'^(?:runner-)?v');

  /// Parses [text], or returns null when it is not a semantic version.
  static RunnerVersion? parse(String text) {
    final trimmed = text.trim();
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;
    final major = int.tryParse(match[1] ?? '');
    final minor = int.tryParse(match[2] ?? '');
    final patch = int.tryParse(match[3] ?? '');
    if (major == null || minor == null || patch == null) return null;
    return RunnerVersion._(
      trimmed.replaceFirst(_prefix, ''),
      major,
      minor,
      patch,
      switch (match[4]) {
        final pre? => pre.split('.'),
        null => const [],
      },
    );
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
  final int patch;

  /// `pre.1` as `['pre', '1']`; empty for a release.
  final List<String> prerelease;

  /// `0.3.x`: the releases compatible with this version.
  String get series => '$major.$minor.x';

  bool isCompatibleWith(RunnerVersion other) =>
      major == other.major && minor == other.minor;

  /// Whether this version comes before [other] in semantic-version order:
  /// `0.3.0-pre.1` before `0.3.0-pre.2` before `0.3.0` before `0.3.1`.
  bool isOlderThan(RunnerVersion other) => _compare(other) < 0;

  int _compare(RunnerVersion other) {
    for (final (mine, theirs) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (mine != theirs) return mine.compareTo(theirs);
    }
    // A release comes after its prereleases.
    final release = switch ((prerelease.isEmpty, other.prerelease.isEmpty)) {
      (true, true) => 0,
      (true, false) => 1,
      (false, true) => -1,
      (false, false) => null,
    };
    if (release case final order?) return order;
    for (var i = 0; i < prerelease.length && i < other.prerelease.length; i++) {
      final order = _compareIdentifier(prerelease[i], other.prerelease[i]);
      if (order != 0) return order;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  /// Numbers by value and before words; words by their characters.
  static int _compareIdentifier(String mine, String theirs) {
    return switch ((int.tryParse(mine), int.tryParse(theirs))) {
      (final a?, final b?) => a.compareTo(b),
      (_?, null) => -1,
      (null, _?) => 1,
      (null, null) => mine.compareTo(theirs),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RunnerVersion && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}
