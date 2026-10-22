import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// A stand-in for the GitHub releases API on the loopback interface: the
/// releases list at `/releases`, newest first, and the archives under
/// `/download/<name>`.
final class FakeReleaseServer {
  FakeReleaseServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeReleaseServer> start() async => FakeReleaseServer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );

  final HttpServer _server;
  final _releases = <Map<String, Object?>>[];
  final _archives = <String, List<int>>{};

  /// The paths requested so far.
  final requests = <String>[];

  Uri get releasesUri => Uri.parse('http://127.0.0.1:${_server.port}/releases');

  /// Adds a release tagged [tag] (`runner-v0.3.1`) with an archive for each of
  /// [platforms], newest first: call it for the newest release first.
  /// [archive] stands in for every platform's archive; without one, the
  /// asset is listed but its download answers 404.
  void addRelease(
    String tag, {
    required List<String> platforms,
    List<int>? archive,
    bool prerelease = false,
    bool draft = false,
  }) {
    final version = tag.replaceFirst(RegExp(r'^(?:runner-)?v'), '');
    _releases.add({
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        for (final platform in platforms)
          {
            'name': 'raccoon_runner-$version-$platform.tar.gz',
            'browser_download_url':
                'http://127.0.0.1:${_server.port}/download/'
                'raccoon_runner-$version-$platform.tar.gz',
          },
      ],
    });
    if (archive == null) return;
    for (final platform in platforms) {
      _archives['raccoon_runner-$version-$platform.tar.gz'] = archive;
    }
  }

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    requests.add(path);
    final response = request.response;
    if (path == '/releases') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(_releases));
      response.close();
      return;
    }
    final archive = switch (path.startsWith('/download/')) {
      true => _archives[path.substring('/download/'.length)],
      false => null,
    };
    if (archive case final bytes?) {
      response.headers.contentType = ContentType.binary;
      response.add(bytes);
      response.close();
      return;
    }
    response.statusCode = HttpStatus.notFound;
    response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// A release archive the way the runner's `tool/package.sh` packs one: the
/// binary (a script here, which prints its version) beside `VERSION`, with
/// the tools, all flat. [entries] adds or replaces files by name.
List<int> fakeRunnerArchive({
  String version = '0.3.0',
  bool withBinary = true,
  Map<String, String> entries = const {},
}) {
  final files = {
    if (withBinary)
      'raccoon_runner': '#!/bin/sh\necho "raccoon_runner $version"\n',
    'tool/raccoon-device': '#!/bin/sh\necho ping\n',
    'tool/engine_dir.sh': '#!/bin/sh\necho engine\n',
    'VERSION': '$version\n',
    'LICENSE': 'BSD-3-Clause\n',
    ...entries,
  };
  final archive = Archive();
  for (final MapEntry(key: name, value: contents) in files.entries) {
    final file = ArchiveFile.string(name, contents);
    if (contents.startsWith('#!')) file.mode = 0x1ed;
    archive.add(file);
  }
  return const GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}
