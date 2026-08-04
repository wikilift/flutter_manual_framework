import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';

void main() {
  test('parsea el manifest remoto canónico', () {
    final manifest = OmniDistributionManifest.parse(
      jsonEncode({
        'manifestVersion': omniDistributionManifestVersion,
        'minimumSdkVersion': '0.1.0',
        'runtimeVersion': '1.8.5',
        'generatedAt': '2026-07-19T12:00:00.000Z',
        'manuals': [
          {
            'id': 'cmc3',
            'displayName': 'CMC3',
            'version': '1.2.0',
            'hashSha256':
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            'compressedSize': 12345,
            'downloadUrl': 'cmc3.zip',
            'languages': ['es', 'en'],
            'dependencies': <String>[],
            'date': '2026-07-19T12:00:00.000Z',
            'icon': 'assets/images/cmc3.svg',
            'poster': 'assets/posters/cmc3.svg',
          },
        ],
        'packages': [
          {
            'id': 'shared_assets',
            'kind': 'assets',
            'version': '1.0.0',
            'hashSha256':
                'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
            'compressedSize': 999,
            'downloadUrl': 'shared_assets.zip',
            'dependencies': <String>[],
            'date': '2026-07-19T12:00:00.000Z',
          },
        ],
        'signature': {
          'algorithm': 'ed25519',
          'keyId': 'future-key',
          'value': 'future-signature',
        },
      }),
    );

    expect(manifest.minimumSdkVersion, '0.1.0');
    expect(manifest.manifestVersion, 1);
    expect(manifest.runtimeVersion, '1.8.5');
    expect(manifest.signature?.algorithm, 'ed25519');
    expect(manifest.packages.single.kind, OmniDistributionPackageKind.assets);
    expect(manifest.manuals.single.toManualInfo().id, 'cmc3');
    expect(
      manifest.manuals.single.toManualInfo().icon,
      'assets/images/cmc3.svg',
    );
  });

  test('rechaza manifests sin campos obligatorios', () {
    expect(
      () => OmniDistributionManifest.parse(
        jsonEncode({
          'manifestVersion': 1,
          'minimumSdkVersion': '0.1.0',
          'runtimeVersion': '1.8.5',
          'generatedAt': '2026-07-19T12:00:00.000Z',
          'manuals': <Object?>[],
        }),
      ),
      returnsNormally,
    );
    expect(
      () => OmniDistributionManifest.parse(jsonEncode({'manuals': []})),
      throwsFormatException,
    );
  });
}
