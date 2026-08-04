import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/src/internal/registry_generator.dart';

void main() {
  test('generator emits a static provider from local manual assets', () {
    final root = Directory.systemTemp.createTempSync('omni_manuals_registry_');
    addTearDown(() => root.deleteSync(recursive: true));

    final manualRoot = Directory('${root.path}/assets/manuals/demo')
      ..createSync(recursive: true);
    Directory(
      '${root.path}/assets/manuals/.editor-backups',
    ).createSync(recursive: true);
    File('${manualRoot.path}/manifest.json').writeAsStringSync('''
{
  "id": "demo",
  "version": "1.2.3",
  "minimumRuntimeVersion": "1.8.5",
  "entrypoint": "manual.json"
}
''');
    File('${manualRoot.path}/manual.json').writeAsStringSync('''
{
  "defaultLanguage": "es",
  "languages": ["es", "en"],
  "content": {"es": "content/es.json"},
  "metadata": {
    "titleKey": "manual.title",
    "subtitleKey": "manual.subtitle"
  }
}
''');
    Directory('${manualRoot.path}/content').createSync();
    File('${manualRoot.path}/content/es.json').writeAsStringSync('''
{
  "manual": {
    "title": "Manual demo",
    "subtitle": "Subtítulo"
  }
}
''');

    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
  assets:
    # BEGIN OMNIMANUAL GENERATED ASSETS
    - assets/omnimanual/runtime/
    - assets/omnimanual/library/
    # END OMNIMANUAL GENERATED ASSETS
''');
    final output = File('${root.path}/lib/omni_manuals_registry.g.dart');

    final result = generateRegistry(
      RegistryGeneratorOptions(
        assetRoot: '${root.path}/assets',
        output: output.path,
        pubspec: pubspec.path,
      ),
    );

    expect(result.manualCount, 1);
    expect(result.collectionCount, 0);
    expect(result.assetDirectoryCount, 2);

    final generated = output.readAsStringSync();
    expect(generated, contains('class GeneratedOmniManualsSource'));
    expect(generated, contains('class GeneratedOmniManualsCatalogSource'));
    expect(generated, contains('Future<Uint8List?> loadAsset'));
    expect(generated, contains('OmniLibraryCatalog.parse'));
    expect(generated, contains('rootBundle.load'));
    expect(generated, contains('manuals/'));
    expect(generated, isNot(contains('viewer-config.json')));
    expect(generated, isNot(contains('runtime/')));
    expect(generated, isNot(contains('library/')));

    final updatedPubspec = pubspec.readAsStringSync();
    expect(updatedPubspec, contains('- ${root.path}/assets/manuals/demo/'));
    expect(
      updatedPubspec,
      contains('- ${root.path}/assets/manuals/demo/content/'),
    );
    expect(updatedPubspec, isNot(contains('assets/omnimanual/runtime')));
    expect(updatedPubspec, isNot(contains('assets/omnimanual/library')));
    expect(updatedPubspec, isNot(contains('.editor-backups')));
  });

  test('generator emits recursive collections and root unassigned manuals', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_collections_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    _writeManual(root, 'beta', 'Beta');
    _writeManual(root, 'gamma', 'Gamma');
    File('${root.path}/assets/collections.json').writeAsStringSync('''
{
  "collections": [
    {
      "id": "setup",
      "title": "Puesta en marcha",
      "manuals": ["alpha"],
      "children": [
        {
          "id": "advanced",
          "title": "Avanzado",
          "manuals": ["beta"]
        }
      ]
    }
  ]
}
''');

    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');
    final output = File('${root.path}/lib/omni_manuals_registry.g.dart');

    final result = generateRegistry(
      RegistryGeneratorOptions(
        assetRoot: '${root.path}/assets',
        output: output.path,
        pubspec: pubspec.path,
      ),
    );

    expect(result.manualCount, 3);
    expect(result.collectionCount, 2);
    final generated = output.readAsStringSync();
    expect(generated, contains('"type":"collection"'));
    expect(generated, contains('"id":"setup"'));
    expect(generated, contains('"id":"advanced"'));
    expect(generated, contains('"manualId":"gamma"'));
    final catalog = generated.substring(
      generated.indexOf('_generatedOmniLibraryCatalogJson'),
    );
    expect(
      catalog.indexOf('"id":"setup"'),
      lessThan(catalog.indexOf('"manualId":"gamma"')),
    );
  });

  test('generator accepts library_catalog.json as canonical catalog', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_library_catalog_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    File('${root.path}/assets/library_catalog.json').writeAsStringSync('''
{
  "schemaVersion": 1,
  "catalogVersion": "local",
  "entries": [
    {
      "type": "collection",
      "id": "setup",
      "title": {"es": "Puesta en marcha"},
      "icon": "settings",
      "children": [
        {"type": "manual", "manualId": "alpha"}
      ]
    }
  ]
}
''');
    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');

    final result = generateRegistry(
      RegistryGeneratorOptions(
        assetRoot: '${root.path}/assets',
        output: '${root.path}/lib/omni_manuals_registry.g.dart',
        pubspec: pubspec.path,
      ),
    );

    expect(result.collectionCount, 1);
    final generated = File(
      '${root.path}/lib/omni_manuals_registry.g.dart',
    ).readAsStringSync();
    expect(generated, isNot(contains('deploymentPolicy')));
    expect(generated, contains('"icon":"settings"'));
  });

  test('generator rejects unsupported Material icons in library_catalog.json', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_library_catalog_bad_icon_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    File('${root.path}/assets/library_catalog.json').writeAsStringSync('''
{
  "schemaVersion": 1,
  "catalogVersion": "local",
  "entries": [
    {
      "type": "collection",
      "id": "setup",
      "title": {"es": "Puesta en marcha"},
      "icon": "xxxxx",
      "children": []
    }
  ]
}
''');
    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');

    expect(
      () => generateRegistry(
        RegistryGeneratorOptions(
          assetRoot: '${root.path}/assets',
          output: '${root.path}/lib/omni_manuals_registry.g.dart',
          pubspec: pubspec.path,
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains("El icono 'xxxxx' no pertenece al catálogo Material soportado"),
        ),
      ),
    );
  });

  test('generator rejects remote asset paths in library_catalog.json', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_library_catalog_remote_asset_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    File('${root.path}/assets/library_catalog.json').writeAsStringSync('''
{
  "schemaVersion": 1,
  "catalogVersion": "local",
  "entries": [
    {
      "type": "manual",
      "manualId": "alpha",
      "image": "https://example.com/cover.png"
    }
  ]
}
''');
    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');

    expect(
      () => generateRegistry(
        RegistryGeneratorOptions(
          assetRoot: '${root.path}/assets',
          output: '${root.path}/lib/omni_manuals_registry.g.dart',
          pubspec: pubspec.path,
        ),
      ),
      throwsFormatException,
    );
  });

  test('generator rejects unknown manual IDs in collections', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_bad_collection_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    File('${root.path}/assets/collections.json').writeAsStringSync('''
{
  "collections": [
    {"id": "setup", "title": "Setup", "manuals": ["missing"]}
  ]
}
''');
    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');

    expect(
      () => generateRegistry(
        RegistryGeneratorOptions(
          assetRoot: '${root.path}/assets',
          output: '${root.path}/lib/omni_manuals_registry.g.dart',
          pubspec: pubspec.path,
        ),
      ),
      throwsFormatException,
    );
  });

  test('generator rejects duplicated manual references in collections', () {
    final root = Directory.systemTemp.createTempSync(
      'omni_manuals_duplicate_collection_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    _writeManual(root, 'alpha', 'Alpha');
    File('${root.path}/assets/collections.json').writeAsStringSync('''
{
  "collections": [
    {"id": "setup", "title": "Setup", "manuals": ["alpha"]},
    {"id": "again", "title": "Again", "manuals": ["alpha"]}
  ]
}
''');
    final pubspec = File('${root.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: fixture

flutter:
  uses-material-design: true
''');

    expect(
      () => generateRegistry(
        RegistryGeneratorOptions(
          assetRoot: '${root.path}/assets',
          output: '${root.path}/lib/omni_manuals_registry.g.dart',
          pubspec: pubspec.path,
        ),
      ),
      throwsFormatException,
    );
  });
}

void _writeManual(Directory root, String id, String title) {
  final manualRoot = Directory('${root.path}/assets/manuals/$id')
    ..createSync(recursive: true);
  File('${manualRoot.path}/manifest.json').writeAsStringSync('''
{
  "id": "$id",
  "version": "1.0.0",
  "entrypoint": "manual.json"
}
''');
  File('${manualRoot.path}/manual.json').writeAsStringSync('''
{
  "defaultLanguage": "es",
  "languages": ["es"],
  "content": {"es": "content/es.json"},
  "metadata": {"titleKey": "manual.title"}
}
''');
  Directory('${manualRoot.path}/content').createSync();
  File('${manualRoot.path}/content/es.json').writeAsStringSync('''
{"manual": {"title": "$title"}}
''');
}
