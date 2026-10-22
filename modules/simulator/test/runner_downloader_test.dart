import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simulator/features/runtime/runtime.dart';

import 'support/fake_release_server.dart';

void main() {
  late Directory temp;
  late FakeReleaseServer server;
  late RunnerDownloader downloader;
  late PrebuiltRunner prebuilt;

  final pinned = RunnerVersion.parse('0.3.0-pre.1') ?? (throw StateError(''));

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('simulator_download');
    server = await FakeReleaseServer.start();
    downloader = RunnerDownloader(
      releases: server.releasesUri,
      platform: 'linux-x64',
    );
    prebuilt = PrebuiltRunner(p.join(temp.path, 'runtime', 'runner'));
  });

  tearDown(() async {
    await server.close();
    temp.deleteSync(recursive: true);
  });

  group('RunnerVersion', () {
    test('parses a version, a prerelease and a tag', () {
      final version = RunnerVersion.parse('0.3.0-pre.1');
      expect(version?.major, 0);
      expect(version?.minor, 3);
      expect(version?.text, '0.3.0-pre.1');
      expect(version?.series, '0.3.x');
      expect(RunnerVersion.parse('v1.2.3')?.text, '1.2.3');
      expect(RunnerVersion.parse('runner-v1.2.3')?.text, '1.2.3');
      expect(RunnerVersion.parse('runner-v1.2.3')?.series, '1.2.x');
      expect(RunnerVersion.parse(' 0.3.1\n')?.text, '0.3.1');
      expect(RunnerVersion.parse('latest'), isNull);
      expect(RunnerVersion.parse('0.3'), isNull);
    });

    test('is compatible within its major and minor', () {
      expect(
        pinned.isCompatibleWith(RunnerVersion.parse('0.3.4') ?? pinned),
        isTrue,
      );
      expect(
        pinned.isCompatibleWith(RunnerVersion.parse('0.4.0') ?? pinned),
        isFalse,
      );
      expect(
        pinned.isCompatibleWith(RunnerVersion.parse('1.3.0') ?? pinned),
        isFalse,
      );
    });

    test('orders prereleases, releases and patches', () {
      final ordered = [
        '0.2.9',
        '0.3.0-pre',
        '0.3.0-pre.1',
        '0.3.0-pre.2',
        '0.3.0-pre.10',
        '0.3.0-pre.x',
        '0.3.0-rc.1',
        '0.3.0',
        '0.3.1',
        '1.0.0',
      ].map((text) => RunnerVersion.parse(text) ?? pinned).toList();
      for (var i = 0; i < ordered.length; i++) {
        for (var j = 0; j < ordered.length; j++) {
          expect(
            ordered[i].isOlderThan(ordered[j]),
            i < j,
            reason: '${ordered[i]} before ${ordered[j]}',
          );
        }
      }
      expect(
        pinned.isOlderThan(RunnerVersion.parse('0.3.0-pre.1+build') ?? pinned),
        isFalse,
      );
    });

    test('reads a VERSION file', () {
      final file = File(p.join(temp.path, 'VERSION'))
        ..writeAsStringSync('0.3.2\n');
      expect(RunnerVersion.read(file.path), RunnerVersion.parse('0.3.2'));
      expect(RunnerVersion.read(p.join(temp.path, 'missing')), isNull);
    });
  });

  test('names the archive for the host', () {
    expect(RunnerDownloader.platformFor('linux', Abi.linuxX64), 'linux-x64');
    expect(
      RunnerDownloader.platformFor('macos', Abi.macosArm64),
      'macos-arm64',
    );
    expect(RunnerDownloader.platformFor('macos', Abi.macosX64), 'macos-x64');
    expect(
      RunnerDownloader.assetName(pinned, 'linux-x64'),
      'raccoon_runner-0.3.0-pre.1-linux-x64.tar.gz',
    );
  });

  test(
    'picks the newest compatible release with an archive for the host',
    () async {
      server
        ..addRelease('runner-v0.4.0', platforms: ['linux-x64'])
        ..addRelease('runner-v0.3.3', platforms: ['linux-x64'], draft: true)
        ..addRelease('runner-v0.3.2', platforms: ['macos-arm64'])
        ..addRelease(
          'runner-v0.3.1',
          platforms: ['linux-x64', 'macos-arm64'],
          prerelease: true,
        )
        ..addRelease('runner-v0.3.0', platforms: ['linux-x64'])
        ..addRelease('runner-v0.2.0', platforms: ['linux-x64']);

      final release = await downloader.find(pinned);

      expect(release?.version, RunnerVersion.parse('0.3.1'));
      expect(release?.prerelease, isTrue);
      expect(
        release?.asset.path,
        endsWith('raccoon_runner-0.3.1-linux-x64.tar.gz'),
      );
    },
  );

  test('skips the protocol package\'s own v tags', () async {
    server
      // The protocol package's release carries runner-like assets here on
      // purpose: the tag alone must rule it out.
      ..addRelease('v0.7.0', platforms: ['linux-x64'])
      ..addRelease('runner-v0.3.1', platforms: ['linux-x64']);

    final release = await downloader.find(pinned);

    expect(release?.version, RunnerVersion.parse('0.3.1'));
    expect(
      release?.asset.path,
      endsWith('raccoon_runner-0.3.1-linux-x64.tar.gz'),
    );
  });

  test('skips a release older than the pin', () async {
    server.addRelease('runner-v0.3.0-pre.1', platforms: ['linux-x64']);
    final newer = RunnerVersion.parse('0.3.0-pre.2') ?? pinned;

    expect(await downloader.find(newer), isNull);
  });

  test('finds nothing without a compatible release for the host', () async {
    server
      ..addRelease('runner-v0.4.0', platforms: ['linux-x64'])
      ..addRelease('runner-v0.3.0', platforms: ['macos-arm64']);

    expect(await downloader.find(pinned), isNull);
  });

  test('unpacks the archive into the runtime directory, executable', () async {
    server.addRelease(
      'runner-v0.3.1',
      platforms: ['linux-x64'],
      archive: fakeRunnerArchive(version: '0.3.1'),
    );
    // Whatever an earlier download left goes away.
    File(p.join(prebuilt.directory, 'stale'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('old');
    final release =
        await downloader.find(pinned) ?? (throw StateError('no release'));

    await downloader.install(release, prebuilt);

    expect(
      RunnerVersion.read(prebuilt.versionFile),
      RunnerVersion.parse('0.3.1'),
    );
    expect(File(prebuilt.deviceHelper).existsSync(), isTrue);
    expect(
      File(p.join(prebuilt.directory, 'tool', 'engine_dir.sh')).existsSync(),
      isTrue,
    );
    expect(File(p.join(prebuilt.directory, 'stale')).existsSync(), isFalse);
    expect(Directory('${prebuilt.directory}.partial').existsSync(), isFalse);
    final ran = await Process.run(prebuilt.binary, const []);
    expect(ran.stdout, 'raccoon_runner 0.3.1\n');
    final ping = await Process.run(prebuilt.deviceHelper, const []);
    expect(ping.stdout, 'ping\n');
  });

  test('leaves an entry that would escape the directory out', () async {
    server.addRelease(
      'runner-v0.3.1',
      platforms: ['linux-x64'],
      archive: fakeRunnerArchive(entries: {'../escaped': 'no'}),
    );
    final release =
        await downloader.find(pinned) ?? (throw StateError('no release'));

    await downloader.install(release, prebuilt);

    expect(File(p.join(temp.path, 'runtime', 'escaped')).existsSync(), isFalse);
    expect(File(prebuilt.binary).existsSync(), isTrue);
  });

  test('refuses an archive without the binary', () async {
    server.addRelease(
      'runner-v0.3.1',
      platforms: ['linux-x64'],
      archive: fakeRunnerArchive(withBinary: false),
    );
    final release =
        await downloader.find(pinned) ?? (throw StateError('no release'));

    await expectLater(
      downloader.install(release, prebuilt),
      throwsA(
        isA<DownloadFailed>().having(
          (e) => e.message,
          'message',
          contains('No raccoon_runner'),
        ),
      ),
    );
    expect(Directory(prebuilt.directory).existsSync(), isFalse);
    expect(Directory('${prebuilt.directory}.partial').existsSync(), isFalse);
  });

  test('refuses something that is not an archive', () async {
    server.addRelease(
      'runner-v0.3.1',
      platforms: ['linux-x64'],
      archive: [1, 2, 3],
    );
    final release =
        await downloader.find(pinned) ?? (throw StateError('no release'));

    await expectLater(
      downloader.install(release, prebuilt),
      throwsA(
        isA<DownloadFailed>().having(
          (e) => e.message,
          'message',
          contains('not a tar.gz'),
        ),
      ),
    );
  });

  test('reports a missing archive', () async {
    server.addRelease('runner-v0.3.1', platforms: ['linux-x64']);
    final release =
        await downloader.find(pinned) ?? (throw StateError('no release'));

    await expectLater(
      downloader.install(release, prebuilt),
      throwsA(
        isA<DownloadFailed>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('reports a list that cannot be fetched or read', () async {
    final elsewhere = RunnerDownloader(
      releases: server.releasesUri.replace(path: '/nowhere'),
      platform: 'linux-x64',
    );
    await expectLater(elsewhere.find(pinned), throwsA(isA<DownloadFailed>()));

    await server.close();
    await expectLater(downloader.find(pinned), throwsA(isA<DownloadFailed>()));
  });
}
