import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/features/runtime/models/models.dart';

/// A download that did not work, with what to tell the user.
final class DownloadFailed implements Exception {
  const DownloadFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A release of the runner with an archive for this host.
final class RunnerRelease {
  const RunnerRelease({
    required this.version,
    required this.asset,
    required this.prerelease,
  });

  final RunnerVersion version;

  /// The archive's download URL.
  final Uri asset;

  final bool prerelease;
}

/// Fetches the prebuilt runner from the Raccoon repository's GitHub
/// releases, the ones tagged `runner-v*` (plain `v*` tags are the protocol
/// package's): the newest release compatible with the checkout's pinned
/// version, and no older, that carries an archive for this host, unpacked into the
/// simulator's runtime directory. The archives come from the runner's `tool/package.sh`:
/// `raccoon_runner-<version>-<platform>.tar.gz`, flat, the binary at the
/// root. Nothing here sets a quarantine attribute, so the binary runs on
/// macOS as it is.
final class RunnerDownloader {
  RunnerDownloader({Uri? releases, String? platform})
    : releases = releases ?? defaultReleases,
      platform = platform ?? hostPlatform;

  /// The Raccoon repository's releases, newest first, prereleases included.
  static final defaultReleases = Uri.parse(
    'https://api.github.com/repos/SoFluffyOS/raccoon/releases?per_page=30',
  );

  /// What a runner release's tag starts with.
  static const tagPrefix = 'runner-v';

  /// The archives' platform name for the host this process runs on.
  static final String hostPlatform = platformFor(
    Platform.operatingSystem,
    Abi.current(),
  );

  /// The archives' platform name for [operatingSystem] on [abi]:
  /// `linux-x64`, `linux-arm64`, `macos-arm64`, `macos-x64`, `windows-x64`
  /// or `windows-arm64`.
  static String platformFor(String operatingSystem, Abi abi) {
    final architecture = switch (abi) {
      Abi.linuxArm64 || Abi.macosArm64 || Abi.windowsArm64 => 'arm64',
      Abi.linuxX64 || Abi.macosX64 || Abi.windowsX64 => 'x64',
      _ => throw UnsupportedError('no prebuilt runner for $abi'),
    };
    return switch (operatingSystem) {
      'linux' || 'macos' || 'windows' => '$operatingSystem-$architecture',
      _ => throw UnsupportedError('no prebuilt runner for $operatingSystem'),
    };
  }

  /// The archive's name in a release, as `tool/package.sh` names it.
  static String assetName(RunnerVersion version, String platform) =>
      'raccoon_runner-$version-$platform.tar.gz';

  final Uri releases;

  /// The archives' platform name this downloader serves, see [platformFor].
  final String platform;

  /// The newest release compatible with [version], and no older than it,
  /// that has an archive for [platform], or null when there is none. Throws [DownloadFailed] when
  /// the list cannot be fetched or read.
  Future<RunnerRelease?> find(RunnerVersion version) async {
    final body = await _get(releases, accept: 'application/vnd.github+json');
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException {
      throw DownloadFailed('$releases did not answer with JSON');
    }
    if (decoded is! List) {
      throw DownloadFailed('$releases did not answer with a list of releases');
    }
    for (final entry in decoded) {
      if (entry is! Map || entry['draft'] == true) continue;
      final tag = entry['tag_name'];
      if (tag is! String || !tag.startsWith(tagPrefix)) continue;
      final candidate = RunnerVersion.parse(tag);
      if (candidate == null || !candidate.isCompatibleWith(version)) continue;
      if (candidate.isOlderThan(version)) continue;
      final url = _assetUrl(entry['assets'], assetName(candidate, platform));
      if (url == null) continue;
      return RunnerRelease(
        version: candidate,
        asset: Uri.parse(url),
        prerelease: entry['prerelease'] == true,
      );
    }
    return null;
  }

  /// Downloads [release]'s archive and unpacks it into [into], replacing
  /// what was there. The binary and the tools come out executable.
  Future<void> install(RunnerRelease release, PrebuiltRunner into) async {
    final bytes = await _get(release.asset);
    final Archive archive;
    try {
      archive = TarDecoder().decodeBytes(
        const GZipDecoder().decodeBytes(bytes),
      );
    } on Object catch (error) {
      throw DownloadFailed('${release.asset} is not a tar.gz archive: $error');
    }
    final directory = Directory(into.directory);
    final staging = Directory('${directory.path}.partial');
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final target = p.normalize(p.join(staging.path, entry.name));
      // An entry that would land outside the folder is left out.
      if (!p.isWithin(staging.path, target)) continue;
      final file = File(target)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entry.content);
      if (entry.mode & _ownerExecutable != 0) _makeExecutable(file);
    }
    final binary = File(p.join(staging.path, p.basename(into.binary)));
    if (!binary.existsSync()) {
      staging.deleteSync(recursive: true);
      throw DownloadFailed(
        'No ${p.basename(into.binary)} in ${release.asset}',
      );
    }
    _makeExecutable(binary);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    staging.renameSync(directory.path);
  }

  static const _ownerExecutable = 0x40;

  static String? _assetUrl(Object? assets, String name) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset
          case {
            'name': final String assetName,
            'browser_download_url': final String url,
          }
          when assetName == name) {
        return url;
      }
    }
    return null;
  }

  static void _makeExecutable(File file) {
    if (Platform.isWindows) return;
    Process.runSync('chmod', ['755', file.path]);
  }

  static Future<List<int>> _get(Uri uri, {String? accept}) async {
    final client = HttpClient()..userAgent = 'raccoon_simulator';
    try {
      final request = await client.getUrl(uri);
      if (accept case final accept?) {
        request.headers.set(HttpHeaders.acceptHeader, accept);
      }
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw DownloadFailed('${response.statusCode} for $uri');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on IOException catch (error) {
      throw DownloadFailed('$uri: $error');
    } finally {
      client.close();
    }
  }
}
