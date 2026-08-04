import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';

void main() {
  test(
    'ZipSource sincroniza paquetes ZIP locales con el mismo servicio',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'omni_zip_source_test_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final zipBytes = _zipBytes({'assets/shared/config.json': '{"ok":true}'});
      final zipFile = File('${temp.path}/shared_assets.zip');
      await zipFile.writeAsBytes(zipBytes);
      final manifestFile = File('${temp.path}/manifest.json');
      await manifestFile.writeAsString(
        jsonEncode({
          'manifestVersion': omniDistributionManifestVersion,
          'minimumSdkVersion': '0.1.0',
          'runtimeVersion': '1.8.5',
          'generatedAt': '2026-07-19T12:00:00.000Z',
          'manuals': <Object?>[],
          'packages': [
            {
              'id': 'shared',
              'kind': 'assets',
              'version': '1.0.0',
              'hashSha256': sha256.convert(zipBytes).toString(),
              'compressedSize': zipBytes.length,
              'downloadUrl': 'shared_assets.zip',
              'dependencies': <String>[],
              'date': '2026-07-19T12:00:00.000Z',
            },
          ],
        }),
      );

      final source = CachedSource(
        upstream: ZipSource(manifestFile: manifestFile),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      );

      await OmniDistributionService(
        source: ZipSource(manifestFile: manifestFile),
        cache: OmniManualsCache(root: Directory('${temp.path}/cache')),
      ).synchronize();

      final assetBytes = await source.loadAsset('assets/shared/config.json');
      expect(assetBytes, isNotNull);
      expect(utf8.decode(assetBytes!), '{"ok":true}');
    },
  );
}

List<int> _zipBytes(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el ZIP de prueba.');
  }
  return encoded;
}
