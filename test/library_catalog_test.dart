import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  test('OmniLocalizedText applies exact, base and default fallbacks', () {
    final text = OmniLocalizedText.fromJson({
      'es': 'Controladores',
      'en': 'Controllers',
    }, 'title');

    expect(text.resolve('es-MX'), 'Controladores');
    expect(text.resolve('fr-FR'), 'Controllers');
    expect(text.resolve(null), 'Controllers');
  });

  test(
    'Library Catalog filters by groups without appending unassigned manuals',
    () {
      final catalog = OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': omniLibraryCatalogSchemaVersion,
          'catalogVersion': 'test',
          'entries': [
            {
              'type': 'collection',
              'id': 'visible',
              'title': {'es': 'Visible'},
              'groups': ['default'],
              'children': [
                {'type': 'manual', 'manualId': 'manual_a'},
                {
                  'type': 'manual',
                  'manualId': 'manual_beta',
                  'groups': ['beta'],
                },
              ],
            },
          ],
        }),
      );

      final entries = catalog.toLibraryEntries(
        registry: const [
          OmniManualInfo(id: 'manual_a', title: 'Manual A'),
          OmniManualInfo(id: 'manual_beta', title: 'Manual Beta'),
          OmniManualInfo(id: 'manual_unassigned', title: 'Manual Unassigned'),
        ],
        language: 'es',
        userGroups: const {'default'},
      );

      final collection = entries.first as OmniCollectionEntry;
      expect(collection.title, 'Visible');
      expect(collection.children.single.id, 'manual_a');
      expect(
        entries.where((entry) => entry.id == 'manual_unassigned'),
        isEmpty,
      );
      expect(entries.where((entry) => entry.id == 'manual_beta'), isEmpty);
    },
  );

  test('Library Catalog keeps declared empty collections', () {
    final catalog = OmniLibraryCatalog.parse(
      jsonEncode({
        'schemaVersion': omniLibraryCatalogSchemaVersion,
        'catalogVersion': 'test',
        'entries': [
          {
            'type': 'collection',
            'id': 'videos',
            'title': {'es': 'Videos'},
            'children': <Object?>[],
          },
        ],
      }),
    );

    final entries = catalog.toLibraryEntries(
      registry: const <OmniManualInfo>[],
      language: 'es',
      userGroups: const {'default'},
    );

    final collection = entries.single as OmniCollectionEntry;
    expect(collection.id, 'videos');
    expect(collection.children, isEmpty);
  });

  test(
    'Library Catalog falls back to default language for missing translations',
    () {
      final catalog = OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': omniLibraryCatalogSchemaVersion,
          'catalogVersion': 'test',
          'defaultLanguage': 'es',
          'entries': [
            {
              'type': 'collection',
              'id': 'setup',
              'title': {'es': 'Puesta en marcha'},
              'children': [
                {
                  'type': 'manual',
                  'manualId': 'manual_a',
                  'title': {'es': 'Manual en español'},
                },
              ],
            },
          ],
        }),
      );

      final entries = catalog.toLibraryEntries(
        registry: const [OmniManualInfo(id: 'manual_a', title: 'Manual A')],
        language: 'en',
        userGroups: const {'default'},
      );

      final collection = entries.single as OmniCollectionEntry;
      expect(collection.title, 'Puesta en marcha');
      expect(
        (collection.children.single as OmniManualLibraryEntry).title,
        'Manual en español',
      );
    },
  );

  test('Library Catalog manual entries omit legacy deploymentPolicy', () {
    final catalog = OmniLibraryCatalog.parse(
      jsonEncode({
        'schemaVersion': omniLibraryCatalogSchemaVersion,
        'catalogVersion': 'test',
        'entries': [
          {'type': 'manual', 'manualId': 'manual_a'},
        ],
      }),
    );

    final entry = catalog.entries.single as OmniLibraryCatalogManual;
    expect(entry.toJson().containsKey('deploymentPolicy'), isFalse);

    final libraryEntry =
        catalog
                .toLibraryEntries(
                  registry: const [OmniManualInfo(id: 'manual_a', title: 'A')],
                  language: 'es',
                  userGroups: const {'default'},
                )
                .single
            as OmniManualLibraryEntry;
    expect(libraryEntry.manual.id, 'manual_a');
  });

  test('Library Catalog rejects legacy deploymentPolicy', () {
    expect(
      () => OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': omniLibraryCatalogSchemaVersion,
          'catalogVersion': 'test',
          'entries': [
            {
              'type': 'manual',
              'manualId': 'manual_a',
              'deploymentPolicy': 'optional',
            },
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test('Library Catalog rejects remote asset paths', () {
    expect(
      () => OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': omniLibraryCatalogSchemaVersion,
          'catalogVersion': 'test',
          'entries': [
            {
              'type': 'manual',
              'manualId': 'manual_a',
              'image': 'https://example.com/image.webp',
            },
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test('Library Catalog uses canonical Material icon names', () {
    final catalog = OmniLibraryCatalog.parse(
      jsonEncode({
        'schemaVersion': omniLibraryCatalogSchemaVersion,
        'catalogVersion': 'test',
        'entries': [
          {
            'type': 'collection',
            'id': 'setup',
            'title': {'es': 'Setup'},
            'icon': 'menu_book',
            'children': [
              {'type': 'manual', 'manualId': 'manual_a', 'icon': 'Folder'},
            ],
          },
        ],
      }),
    );

    final collection = catalog.entries.single as OmniLibraryCatalogCollection;
    final manual = collection.children.single as OmniLibraryCatalogManual;
    expect(collection.icon, 'menu_book');
    expect(manual.icon, 'folder');
    expect(OmniMaterialIcons.iconData('menu_book'), Icons.menu_book);
    expect(OmniMaterialIcons.iconData('controllers'), Icons.memory);
  });

  test('Library Catalog rejects unsupported Material icon names', () {
    expect(
      () => OmniLibraryCatalog.parse(
        jsonEncode({
          'schemaVersion': omniLibraryCatalogSchemaVersion,
          'catalogVersion': 'test',
          'entries': [
            {
              'type': 'collection',
              'id': 'setup',
              'title': {'es': 'Setup'},
              'icon': 'xxxxx',
              'children': [],
            },
          ],
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains(
            "El icono 'xxxxx' no pertenece al catálogo Material soportado",
          ),
        ),
      ),
    );
  });

  test(
    'Material icon mapper stays synchronized with the canonical JSON catalog',
    () {
      final source =
          jsonDecode(File('tool/material_icons.json').readAsStringSync())
              as Map<String, Object?>;
      final categories = source['categories'] as List<Object?>;
      final expected = <String>{
        for (final category in categories.cast<Map<String, Object?>>())
          ...(category['icons'] as List<Object?>).cast<String>(),
      };
      final aliases = (source['legacyAliases'] as Map<String, Object?>)
          .cast<String, Object?>();

      expect(OmniMaterialIcons.names, expected);
      for (final entry in aliases.entries) {
        expect(OmniMaterialIcons.normalize(entry.key), entry.value);
      }
    },
  );

  test('default catalog cache is isolated by endpoint', () async {
    final temp = await Directory.systemTemp.createTemp('omni_catalog_support_');
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(temp.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previous;
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final first = await OmniLibraryCatalogCache.defaultCache(
      endpoint: Uri.parse('https://example.com/api/v1/manuals/catalog'),
    );
    final second = await OmniLibraryCatalogCache.defaultCache(
      endpoint: Uri.parse('https://other.example.com/api/v1/manuals/catalog'),
    );

    expect(first.root.path, isNot(second.root.path));
    expect(first.root.path, contains('/omni_manuals/library_catalog/'));
    expect(second.root.path, contains('/omni_manuals/library_catalog/'));
  });

  test(
    'CachedCatalogSource refresh uses 304 and loadCatalog stays local',
    () async {
      final temp = await Directory.systemTemp.createTemp('omni_catalog_cache_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      var requests = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      unawaited(
        server.forEach((request) {
          requests += 1;
          if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v1"') {
            request.response
              ..statusCode = HttpStatus.notModified
              ..headers.set(HttpHeaders.etagHeader, '"v1"')
              ..close();
            return;
          }
          request.response
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/json')
            ..headers.set(HttpHeaders.etagHeader, '"v1"')
            ..write(
              jsonEncode({
                'schemaVersion': omniLibraryCatalogSchemaVersion,
                'catalogVersion': 'v1',
                'entries': [
                  {
                    'type': 'manual',
                    'manualId': 'manual_a',
                    'title': {'en': 'Remote title'},
                  },
                ],
              }),
            )
            ..close();
        }),
      );

      final source = OmniCachedCatalogSource(
        remote: OmniRemoteCatalogSource(
          endpoint: Uri.parse(
            'http://127.0.0.1:${server.port}/api/v1/manuals/catalog',
          ),
        ),
        cache: OmniLibraryCatalogCache(root: temp),
      );

      expect(await source.loadCatalog(), isNull);
      expect(requests, 0);

      await source.refresh();
      final first = await source.loadCatalog();
      await source.refresh();
      final second = await source.loadCatalog();

      expect(first?.catalogVersion, 'v1');
      expect(second?.catalogVersion, 'v1');
      expect(requests, 2);
    },
  );

  test('Catalog cache is not replaced by corrupt JSON', () async {
    final temp = await Directory.systemTemp.createTemp('omni_catalog_corrupt_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    var corrupt = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.forEach((request) {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json',
        );
        if (corrupt) {
          request.response.write('{bad-json');
        } else {
          request.response.write(
            jsonEncode({
              'schemaVersion': omniLibraryCatalogSchemaVersion,
              'catalogVersion': 'valid',
              'entries': [
                {'type': 'manual', 'manualId': 'manual_a'},
              ],
            }),
          );
        }
        request.response.close();
      }),
    );

    final source = OmniCachedCatalogSource(
      remote: OmniRemoteCatalogSource(
        endpoint: Uri.parse(
          'http://127.0.0.1:${server.port}/api/v1/manuals/catalog',
        ),
      ),
      cache: OmniLibraryCatalogCache(root: temp),
    );

    await source.refresh();
    expect((await source.loadCatalog())?.catalogVersion, 'valid');
    corrupt = true;
    await source.refresh().catchError((_) {});
    expect((await source.loadCatalog())?.catalogVersion, 'valid');
  });
}

final class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.applicationSupportPath);

  final String applicationSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;
}
