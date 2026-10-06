import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';
import 'package:omni_manuals/src/internal/manual_metadata.dart';
import 'package:omni_manuals/src/internal/sdk_controller.dart';

void main() {
  test(
    'controller resolves bundled/source metadata on locale changes',
    () async {
      final controller = OmniManualsController();
      addTearDown(controller.dispose);
      await controller.initialize(
        config: OmniManualsConfig(source: _LocalizedSource()),
      );
      final english = await controller.resolveLibraryEntries(language: 'en-US');
      final spanish = await controller.resolveLibraryEntries(language: 'es');
      expect(english.single.title, 'English');
      expect(english.single.subtitle, 'Sub EN');
      expect(spanish.single.title, 'Español');
      expect(english.single.id, spanish.single.id);
    },
  );
  test(
    'localized resolution has one generic deterministic fallback policy',
    () {
      const text = OmniLocalizedText({'es': 'Maniobras', 'en': 'Controllers'});
      expect(text.resolve('en'), 'Controllers');
      expect(text.resolve('en-US'), 'Controllers');
      expect(text.resolve('fr', defaultLanguage: 'es'), 'Maniobras');
      expect(text.resolve('fr', defaultLanguage: 'pt'), 'Controllers');
      expect(
        const OmniLocalizedText({
          'it': 'Manuali',
          'es': 'Manuales',
        }).resolve('de'),
        'Manuales',
      );
      expect(
        const OmniLocalizedText({'es': 'Maniobras'}).resolve('en'),
        'Maniobras',
      );
      expect(const OmniLocalizedText({}).resolve('en'), '');
    },
  );

  test(
    'nested collections and manual presentation respect requested locale',
    () {
      final catalog = OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': 1,
          'catalogVersion': 'same',
          'defaultLanguage': 'es',
          'entries': [
            {
              'type': 'collection',
              'id': 'root',
              'title': {'es': 'Raíz', 'en': 'Root'},
              'children': [
                {
                  'type': 'collection',
                  'id': 'child',
                  'title': {'es': 'Hija', 'en': 'Child'},
                  'subtitle': {'es': 'Sub', 'en': 'Subtitle'},
                  'description': {'es': 'Descripción', 'en': 'Description'},
                  'children': [
                    {
                      'type': 'manual',
                      'manualId': 'manual',
                      'title': {'es': 'Manual ES', 'en': 'Manual EN'},
                      'subtitle': {'es': 'Sub ES', 'en': 'Sub EN'},
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      final root =
          catalog
                  .toLibraryEntries(
                    registry: const [
                      OmniManualInfo(id: 'manual', title: 'Legacy'),
                    ],
                    language: 'en-US',
                    userGroups: const {'default'},
                  )
                  .single
              as OmniCollectionEntry;
      final child = root.children.single as OmniCollectionEntry;
      expect(root.title, 'Root');
      expect(child.title, 'Child');
      expect(child.subtitle, 'Subtitle');
      expect(child.description, 'Description');
      expect(child.children.single.title, 'Manual EN');
      expect(child.children.single.subtitle, 'Sub EN');
      final fallback = catalog
          .toLibraryEntries(
            registry: const [],
            language: 'fr',
            userGroups: const {'default'},
          )
          .single;
      expect(fallback.title, 'Raíz');
    },
  );

  test(
    'package metadata reads requested content and preserves identity',
    () async {
      final files = {
        'manual.json': jsonEncode({
          'id': 'uuid',
          'defaultLanguage': 'es',
          'languages': ['es', 'en'],
          'metadata': {
            'titleKey': 'manual.title',
            'subtitleKey': 'manual.subtitle',
          },
          'content': {'es': 'content/es.json', 'en': 'content/en.json'},
        }),
        'content/es.json': jsonEncode({
          'manual': {'title': 'Español', 'subtitle': 'Sub ES'},
        }),
        'content/en.json': jsonEncode({
          'manual': {'title': 'English', 'subtitle': 'Sub EN'},
        }),
      };
      final metadata = await readManualMetadata(
        loadText: (path) async => files[path],
        fallbackId: 'uuid',
        language: 'en-US',
      );
      expect(metadata?.id, 'uuid');
      expect(metadata?.title, 'English');
      expect(metadata?.subtitle, 'Sub EN');
    },
  );

  test(
    'catalog updates detect presentation and groups changes, not identical 200',
    () async {
      final directory = await Directory.systemTemp.createTemp('catalog_i18n_');
      addTearDown(() => directory.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      Map<String, Object?> entry = {
        'type': 'collection',
        'id': 'root',
        'title': {'es': 'Maniobras'},
        'children': <Object?>[],
      };
      unawaited(
        server.forEach((request) async {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'schemaVersion': 1,
              'catalogVersion': 'unchanged',
              'entries': [entry],
            }),
          );
          await request.response.close();
        }),
      );
      final source = OmniCachedCatalogSource(
        remote: OmniRemoteCatalogSource(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/catalog'),
        ),
        cache: OmniLibraryCatalogCache(root: directory),
      );
      expect(await source.refreshIfValid(), isTrue);
      expect(await source.hasRemoteUpdate(), isFalse);
      expect(await source.refreshIfValid(), isFalse);
      for (final change in [
        {
          'title': {'es': 'Maniobras', 'en': 'Controllers'},
        },
        {
          'title': {'es': 'Maniobras', 'en': 'Elevator Controllers'},
        },
        {
          'title': {'es': 'Maniobras'},
        },
        {
          'subtitle': {'en': 'Subtitle'},
        },
        {
          'description': {'en': 'Description'},
        },
        {
          'groups': ['default', 'technicians'],
        },
        {
          'metadata': {
            'localized': {'en': 'Display'},
          },
        },
      ]) {
        entry = {...entry, ...change};
        expect(await source.hasRemoteUpdate(), isTrue, reason: '$change');
        expect(await source.refreshIfValid(), isTrue);
        expect(await source.hasRemoteUpdate(), isFalse);
      }
    },
  );
}

final class _LocalizedSource extends OmniManualsSource {
  @override
  Future<List<OmniManualInfo>> loadManuals() async => const [
    OmniManualInfo(id: 'manual', title: 'Español'),
  ];

  @override
  Future<Uint8List?> loadAsset(String relativePath) async {
    final files = {
      'manuals/manual/manual.json': {
        'id': 'manual',
        'defaultLanguage': 'es',
        'languages': ['es', 'en'],
        'metadata': {
          'titleKey': 'manual.title',
          'subtitleKey': 'manual.subtitle',
        },
        'content': {'es': 'content/es.json', 'en': 'content/en.json'},
      },
      'manuals/manual/content/es.json': {
        'manual': {'title': 'Español', 'subtitle': 'Sub ES'},
      },
      'manuals/manual/content/en.json': {
        'manual': {'title': 'English', 'subtitle': 'Sub EN'},
      },
    };
    final value = files[relativePath];
    return value == null
        ? null
        : Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }
}
