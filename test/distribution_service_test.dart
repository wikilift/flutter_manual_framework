import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';

void main() {
  test(
    'initialize y loadManuals no realizan red con fuentes cacheadas',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_no_network_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
        await OmniManuals.dispose();
      });
      final remote = _CountingDistributionSource(
        manifest: _singleManualManifest('remote', 'Remote', <int>[1, 2, 3]),
        zipBytes: <int>[1, 2, 3],
      );
      final source = CachedSource(
        upstream: remote,
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );

      expect(await source.loadManuals(), isEmpty);
      await OmniManuals.initialize(config: OmniManualsConfig(source: source));

      expect(OmniManuals.manuals, isEmpty);
      expect(remote.manifestFetches, 0);
      expect(remote.packageOpens, 0);
    },
  );

  test('checkForUpdates no descarga ZIP ni modifica registry', () async {
    final temp = await Directory.systemTemp.createTemp('omni_check_only_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final zipBytes = _zipBytes({'manuals/remote/manual.json': '{"ok":true}'});
    final remote = _CountingDistributionSource(
      manifest: _singleManualManifest('remote', 'Remote', zipBytes),
      zipBytes: zipBytes,
    );
    final cache = OmniManualsCache(root: Directory('${temp.path}/cache'));
    final source = CachedSource(upstream: remote, cache: cache);

    final summary = await source.checkForUpdates();

    expect(summary.newManuals.single.manualId, 'remote');
    expect(remote.manifestFetches, 1);
    expect(remote.packageOpens, 0);
    expect(await cache.loadRegistry(), isNull);
    expect(await source.loadAsset('manuals/remote/manual.json'), isNull);
  });

  test(
    'OmniCompositeSource combina bundled y cache con prioridad cacheada',
    () async {
      final bundled = _MemoryAssetSource(
        manuals: const [
          OmniManualInfo(id: 'a', title: 'Bundled A', version: '1.0.0'),
          OmniManualInfo(id: 'b', title: 'Bundled B', version: '1.0.0'),
        ],
        assets: {
          'manuals/a/manual.json': utf8.encode('bundled-a'),
          'manuals/b/manual.json': utf8.encode('bundled-b'),
        },
      );
      final cached = _MemoryAssetSource(
        manuals: const [
          OmniManualInfo(id: 'a', title: 'Cached A', version: '1.1.0'),
        ],
        assets: {'manuals/a/manual.json': utf8.encode('cached-a')},
      );
      final source = OmniCompositeSource(bundled: bundled, cached: cached);

      final manuals = await source.loadManuals();

      expect(manuals.map((manual) => manual.id), ['a', 'b']);
      expect(manuals.first.title, 'Cached A');
      expect(
        utf8.decode((await source.loadAsset('manuals/a/manual.json'))!),
        'cached-a',
      );
      expect(
        utf8.decode((await source.loadAsset('manuals/b/manual.json'))!),
        'bundled-b',
      );
    },
  );

  test(
    'CachedSource descarga diferencias, valida SHA256 y sirve assets',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_dist_test_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        if (await temp.exists()) await temp.delete(recursive: true);
        await OmniManuals.dispose();
      });

      final zipBytes = _manualPackageZip(
        id: 'cmc3',
        title: 'Manual CMC3',
        subtitle: 'Subtítulo CMC3',
      );
      final hash = sha256.convert(zipBytes).toString();
      final manifest = jsonEncode({
        'manifestVersion': omniDistributionManifestVersion,
        'minimumSdkVersion': '0.1.0',
        'runtimeVersion': '1.8.5',
        'generatedAt': '2026-07-19T12:00:00.000Z',
        'manuals': [
          {
            'id': 'cmc3',
            'displayName': 'CMC3',
            'version': '1.0.0',
            'hashSha256': hash,
            'compressedSize': zipBytes.length,
            'downloadUrl': 'cmc3.zip',
            'languages': ['es', 'en'],
            'dependencies': <String>[],
            'date': '2026-07-19T12:00:00.000Z',
          },
        ],
      });

      server.listen((request) async {
        if (request.uri.path == '/manifest.json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(manifest);
        } else if (request.uri.path == '/cmc3.zip') {
          request.response.add(zipBytes);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final source = CachedSource(
        upstream: HttpSource(endpoint: _endpoint(server)),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );

      expect(await source.loadManuals(), isEmpty);
      final summary = await source.checkForUpdates();
      expect(summary.newManuals.single.manualId, 'cmc3');
      await source.synchronizeAllAvailable();
      final manuals = await source.loadManuals();
      expect(manuals.single.id, 'cmc3');
      expect(manuals.single.title, 'Manual CMC3');
      expect(manuals.single.subtitle, 'Subtítulo CMC3');
      final manualBytes = await source.loadAsset('manuals/cmc3/manual.json');
      expect(manualBytes, isNotNull);
      expect(utf8.decode(manualBytes!), contains('"titleKey":"manual.title"'));
    },
  );

  test(
    'OmniManuals.initialize no realiza red y la sincronización es explícita',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_http_test_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        if (await temp.exists()) await temp.delete(recursive: true);
        await OmniManuals.dispose();
      });

      final zipBytes = _zipBytes({'manuals/demo/manual.json': '{"ok":true}'});
      final hash = sha256.convert(zipBytes).toString();
      final manifest = jsonEncode({
        'manifestVersion': omniDistributionManifestVersion,
        'minimumSdkVersion': '0.1.0',
        'runtimeVersion': '1.8.5',
        'generatedAt': '2026-07-19T12:00:00.000Z',
        'manuals': [
          {
            'id': 'demo',
            'displayName': 'Demo',
            'version': '1.0.0',
            'hashSha256': hash,
            'compressedSize': zipBytes.length,
            'downloadUrl': 'demo.zip',
            'languages': ['es'],
            'dependencies': <String>[],
            'date': '2026-07-19T12:00:00.000Z',
          },
        ],
      });

      server.listen((request) async {
        if (request.uri.path == '/manifest.json') {
          request.response.write(manifest);
        } else if (request.uri.path == '/demo.zip') {
          request.response.add(zipBytes);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final cachedSource = CachedSource(
        upstream: HttpSource(endpoint: _endpoint(server)),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );
      await OmniManuals.initialize(
        config: OmniManualsConfig(source: cachedSource),
      );

      expect(OmniManuals.manuals, isEmpty);
      final summary = await OmniManuals.checkForUpdates();
      expect(summary.newManuals.single.manualId, 'demo');
      await OmniManuals.synchronizeAllAvailable();
      expect(OmniManuals.manuals.single.id, 'demo');
      expect(OmniManuals.manual('demo').title, 'demo');
    },
  );

  test(
    'descarga sólo el ZIP modificado y conserva el resto de la cache',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_update_test_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var cmc3Downloads = 0;
      var manifestVersion = 1;
      final sharedZip = _zipBytes({'assets/shared/config.json': '{"v":1}'});
      var cmc3Zip = _zipBytes({'manuals/cmc3/manual.json': '{"v":1}'});
      addTearDown(() async {
        await server.close(force: true);
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      String manifest() => jsonEncode({
        'manifestVersion': omniDistributionManifestVersion,
        'minimumSdkVersion': '0.1.0',
        'runtimeVersion': '1.8.5',
        'generatedAt': '2026-07-19T12:00:00.000Z',
        'manuals': [
          {
            'id': 'cmc3',
            'displayName': 'CMC3',
            'version': '1.0.$manifestVersion',
            'hashSha256': sha256.convert(cmc3Zip).toString(),
            'compressedSize': cmc3Zip.length,
            'downloadUrl': 'cmc3.zip',
            'languages': ['es'],
            'dependencies': ['shared'],
            'date': '2026-07-19T12:00:00.000Z',
          },
        ],
        'packages': [
          {
            'id': 'shared',
            'kind': 'assets',
            'version': '1.0.0',
            'hashSha256': sha256.convert(sharedZip).toString(),
            'compressedSize': sharedZip.length,
            'downloadUrl': 'shared_assets.zip',
            'dependencies': <String>[],
            'date': '2026-07-19T12:00:00.000Z',
          },
        ],
      });

      server.listen((request) async {
        if (request.uri.path == '/manifest.json') {
          request.response.write(manifest());
        } else if (request.uri.path == '/cmc3.zip') {
          cmc3Downloads += 1;
          request.response.add(cmc3Zip);
        } else if (request.uri.path == '/shared_assets.zip') {
          request.response.add(sharedZip);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final source = CachedSource(
        upstream: HttpSource(endpoint: _endpoint(server)),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );

      await source.synchronizeAllAvailable();
      expect(cmc3Downloads, 1);

      manifestVersion = 2;
      cmc3Zip = _zipBytes({'manuals/cmc3/manual.json': '{"v":2}'});
      final summary = await source.checkForUpdates();
      expect(summary.updates.single.manualId, 'cmc3');
      await source.synchronizeAllAvailable();

      expect(cmc3Downloads, 2);
      final manualBytes = await source.loadAsset('manuals/cmc3/manual.json');
      final assetBytes = await source.loadAsset('assets/shared/config.json');
      expect(utf8.decode(manualBytes!), '{"v":2}');
      expect(utf8.decode(assetBytes!), '{"v":1}');
    },
  );

  test(
    'check no elimina retirados y reconcile puede purgar explícitamente',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_remove_test_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var includeManual = true;
      final cmc3Zip = _zipBytes({
        'manuals/cmc3/manual.json': '{"active":true}',
      });
      addTearDown(() async {
        await server.close(force: true);
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      String manifest() => jsonEncode({
        'manifestVersion': omniDistributionManifestVersion,
        'minimumSdkVersion': '0.1.0',
        'runtimeVersion': '1.8.5',
        'generatedAt': '2026-07-19T12:00:00.000Z',
        'manuals': includeManual
            ? [
                {
                  'id': 'cmc3',
                  'displayName': 'CMC3',
                  'version': '1.0.0',
                  'hashSha256': sha256.convert(cmc3Zip).toString(),
                  'compressedSize': cmc3Zip.length,
                  'downloadUrl': 'cmc3.zip',
                  'languages': ['es'],
                  'dependencies': <String>[],
                  'date': '2026-07-19T12:00:00.000Z',
                },
              ]
            : <Object?>[],
      });

      server.listen((request) async {
        if (request.uri.path == '/manifest.json') {
          request.response.write(manifest());
        } else if (request.uri.path == '/cmc3.zip') {
          request.response.add(cmc3Zip);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final source = CachedSource(
        upstream: HttpSource(endpoint: _endpoint(server)),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );

      await source.synchronizeAllAvailable();
      expect((await source.loadManuals()).single.id, 'cmc3');
      expect(await source.loadAsset('manuals/cmc3/manual.json'), isNotNull);

      includeManual = false;
      final summary = await source.checkForUpdates();
      expect(summary.noLongerAvailable.single.manualId, 'cmc3');
      expect((await source.loadManuals()).single.id, 'cmc3');
      await source.reconcileInstalledContent(removeUnavailable: true);
      expect(await source.loadAsset('manuals/cmc3/manual.json'), isNull);
    },
  );

  test('extracción ZIP acepta directorios y archivos vacíos', () async {
    final temp = await Directory.systemTemp.createTemp('omni_zip_empty_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final zipBytes = _zipArchive([
      ArchiveFile('manuals/empty/', 0, <int>[])..isFile = false,
      ArchiveFile('manuals/empty/manual.json', 0, <int>[]),
    ]);
    final source = CachedSource(
      upstream: _CountingDistributionSource(
        manifest: _singleManualManifest('empty', 'Empty', zipBytes),
        zipBytes: zipBytes,
      ),
      cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
    );

    await source.synchronizeAllAvailable();

    final bytes = await source.loadAsset('manuals/empty/manual.json');
    expect(bytes, isNotNull);
    expect(bytes, isEmpty);
  });

  test('extracción ZIP rechaza paquetes corruptos', () async {
    final temp = await Directory.systemTemp.createTemp('omni_zip_corrupt_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final zipBytes = utf8.encode('no-es-un-zip');
    final source = CachedSource(
      upstream: _CountingDistributionSource(
        manifest: _singleManualManifest('broken', 'Broken', zipBytes),
        zipBytes: zipBytes,
      ),
      cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
    );

    await expectLater(source.synchronizeAllAvailable(), throwsException);
    expect(await source.loadAsset('manuals/broken/manual.json'), isNull);
  });

  test('extracción ZIP bloquea Zip Slip', () async {
    final temp = await Directory.systemTemp.createTemp('omni_zip_slip_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final zipBytes = _zipBytes({'../evil.txt': 'bad'});
    final source = CachedSource(
      upstream: _CountingDistributionSource(
        manifest: _singleManualManifest('slip', 'Slip', zipBytes),
        zipBytes: zipBytes,
      ),
      cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
    );

    await expectLater(
      source.synchronizeAllAvailable(),
      throwsA(isA<OmniManualsException>()),
    );
    expect(await File('${temp.path}/evil.txt').exists(), isFalse);
  });

  test('extracción ZIP rechaza tamaño total descomprimido excesivo', () async {
    final temp = await Directory.systemTemp.createTemp('omni_zip_huge_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final zipBytes = _zipArchive([
      ArchiveFile('manuals/huge/manual.json', 1024 * 1024 * 1024 + 1, <int>[]),
    ]);
    final source = CachedSource(
      upstream: _CountingDistributionSource(
        manifest: _singleManualManifest('huge', 'Huge', zipBytes),
        zipBytes: zipBytes,
      ),
      cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
    );

    await expectLater(
      source.synchronizeAllAvailable(),
      throwsA(isA<OmniManualsException>()),
    );
    expect(await source.loadAsset('manuals/huge/manual.json'), isNull);
  });
}

Uri _endpoint(HttpServer server) => Uri(
  scheme: 'http',
  host: InternetAddress.loopbackIPv4.address,
  port: server.port,
);

OmniDistributionManifest _singleManualManifest(
  String id,
  String title,
  List<int> zipBytes,
) {
  return OmniDistributionManifest(
    manifestVersion: omniDistributionManifestVersion,
    minimumSdkVersion: '0.1.0',
    runtimeVersion: '1.8.5',
    generatedAt: DateTime.parse('2026-07-19T12:00:00.000Z'),
    manuals: [
      OmniDistributionManual(
        id: id,
        displayName: title,
        version: '1.0.0',
        hashSha256: sha256.convert(zipBytes).toString(),
        compressedSize: zipBytes.length,
        downloadUrl: Uri.parse('$id.zip'),
        languages: const ['es'],
        date: DateTime.parse('2026-07-19T12:00:00.000Z'),
      ),
    ],
  );
}

final class _CountingDistributionSource extends OmniManualsDistributionSource {
  _CountingDistributionSource({required this.manifest, required this.zipBytes});

  final OmniDistributionManifest manifest;
  final List<int> zipBytes;
  int _manifestFetches = 0;
  int _packageOpens = 0;

  int get manifestFetches => _manifestFetches;
  int get packageOpens => _packageOpens;

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[];

  @override
  Future<OmniDistributionManifest> fetchManifest() async {
    _manifestFetches += 1;
    return manifest;
  }

  @override
  Future<Stream<List<int>>> openPackage(OmniDistributionPackage package) async {
    _packageOpens += 1;
    return Stream<List<int>>.value(zipBytes);
  }
}

final class _MemoryAssetSource extends OmniManualsSource {
  const _MemoryAssetSource({required this.manuals, required this.assets});

  final List<OmniManualInfo> manuals;
  final Map<String, List<int>> assets;

  @override
  Future<List<OmniManualInfo>> loadManuals() async => manuals;

  @override
  Future<Uint8List?> loadAsset(String relativePath) async {
    final bytes = assets[relativePath];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }
}

List<int> _zipBytes(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return _encodeArchive(archive);
}

List<int> _zipArchive(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  return _encodeArchive(archive);
}

List<int> _encodeArchive(Archive archive) {
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el ZIP de prueba.');
  }
  return encoded;
}

List<int> _manualPackageZip({
  required String id,
  required String title,
  String? subtitle,
}) {
  final metadata = <String, Object?>{'titleKey': 'manual.title'};
  final localizedManual = <String, Object?>{'title': title};
  if (subtitle != null) {
    metadata['subtitleKey'] = 'manual.subtitle';
    localizedManual['subtitle'] = subtitle;
  }
  return _zipBytes({
    'manifest.json': jsonEncode({
      'id': id,
      'version': '1.0.0',
      'entrypoint': 'manual.json',
    }),
    'manual.json': jsonEncode({
      'id': id,
      'formatVersion': 1,
      'defaultLanguage': 'es',
      'languages': ['es', 'en'],
      'metadata': metadata,
      'content': {'es': 'content/es.json', 'en': 'content/en.json'},
      'sections': <Object?>[],
    }),
    'content/es.json': jsonEncode({'manual': localizedManual}),
    'content/en.json': jsonEncode({'manual': localizedManual}),
  });
}
