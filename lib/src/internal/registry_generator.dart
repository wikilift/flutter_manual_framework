import 'dart:convert';
import 'dart:io';

import '../material_icons.dart';

const int _libraryCatalogSchemaVersion = 1;
const int _maxCatalogJsonBytes = 1024 * 1024;
const int _maxCatalogDepth = 16;
const int _maxCatalogEntriesPerList = 1000;
const int _maxLocalizedValues = 32;
const int _maxBadges = 32;
const int _maxMetadataKeys = 64;
final RegExp _safeIdentifier = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

final class RegistryGeneratorOptions {
  const RegistryGeneratorOptions({
    required this.assetRoot,
    required this.output,
    required this.pubspec,
    this.className = defaultClassName,
    this.help = false,
  });

  static const String defaultAssetRoot = 'assets';
  static const String defaultOutput = 'lib/omni_manuals_registry.g.dart';
  static const String defaultPubspec = 'pubspec.yaml';
  static const String defaultClassName = 'GeneratedOmniManualsSource';

  final String assetRoot;
  final String output;
  final String pubspec;
  final String className;
  final bool help;

  static const String usage = '''
Usage:
  dart run omni_manuals:generate

Options:
  --asset-root <path>   Directorio raíz que contiene manuals/.
                        Valor por defecto: assets

  --output <path>       Archivo Dart que se generará.
                        Valor por defecto: lib/omni_manuals_registry.g.dart

  --pubspec <path>      Pubspec que se actualizará.
                        Valor por defecto: pubspec.yaml

  --class-name <name>   Nombre de la clase generada.
                        Valor por defecto: GeneratedOmniManualsSource

  --help, -h            Muestra esta ayuda.
''';

  factory RegistryGeneratorOptions.parse(List<String> arguments) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      return const RegistryGeneratorOptions(
        assetRoot: defaultAssetRoot,
        output: defaultOutput,
        pubspec: defaultPubspec,
        help: true,
      );
    }

    const supportedArguments = <String>{
      '--asset-root',
      '--output',
      '--pubspec',
      '--class-name',
    };

    final values = <String, String>{};

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];

      if (!supportedArguments.contains(argument)) {
        throw FormatException('Argumento no reconocido: $argument');
      }

      if (index + 1 >= arguments.length) {
        throw FormatException('Falta valor para $argument');
      }

      final value = arguments[index + 1];

      if (value.isEmpty || value.startsWith('--')) {
        throw FormatException('Falta valor para $argument');
      }

      values[argument] = value;
      index += 1;
    }

    return RegistryGeneratorOptions(
      assetRoot: values['--asset-root'] ?? defaultAssetRoot,
      output: values['--output'] ?? defaultOutput,
      pubspec: values['--pubspec'] ?? defaultPubspec,
      className: values['--class-name'] ?? defaultClassName,
    );
  }
}

final class RegistryGenerationResult {
  const RegistryGenerationResult({
    required this.manualCount,
    required this.collectionCount,
    required this.assetDirectoryCount,
    required this.registryOutput,
    required this.pubspecPath,
  });

  final int manualCount;
  final int collectionCount;
  final int assetDirectoryCount;
  final String registryOutput;
  final String pubspecPath;
}

RegistryGenerationResult generateRegistry(RegistryGeneratorOptions options) {
  final assetRoot = Directory(options.assetRoot);
  final output = File(options.output);
  final pubspec = File(options.pubspec);

  if (!assetRoot.existsSync()) {
    throw FileSystemException(
      'No existe el directorio raíz de assets',
      assetRoot.path,
    );
  }

  if (!pubspec.existsSync()) {
    throw FileSystemException('No existe el pubspec', pubspec.path);
  }

  final manuals = discoverManuals(assetRoot);
  final libraryCatalogJson = discoverLibraryCatalogJson(assetRoot, manuals);
  final assetDirectories = discoverAssetDirectories(assetRoot);

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    renderRegistry(
      className: options.className,
      assetRoot: options.assetRoot,
      manuals: manuals,
      libraryCatalogJson: libraryCatalogJson,
    ),
  );

  synchronizePubspecAssets(
    pubspecFile: pubspec,
    assetRoot: options.assetRoot,
    assetDirectories: assetDirectories,
  );

  return RegistryGenerationResult(
    manualCount: manuals.length,
    collectionCount: _countCatalogCollections(
      jsonDecode(libraryCatalogJson) as Map<String, Object?>,
    ),
    assetDirectoryCount: assetDirectories.length,
    registryOutput: output.path,
    pubspecPath: pubspec.path,
  );
}

List<GeneratedManual> discoverManuals(Directory assetRoot) {
  final manualsRoot = Directory('${assetRoot.path}/manuals');

  if (!manualsRoot.existsSync()) {
    throw FileSystemException(
      'No existe el directorio de manuales',
      manualsRoot.path,
    );
  }

  final manuals = <GeneratedManual>[];

  for (final entity in manualsRoot.listSync(followLinks: true)) {
    if (entity is! Directory) {
      continue;
    }

    final folderName = _basename(entity.path);

    if (folderName.startsWith('_') || _shouldIgnoreAssetSegment(folderName)) {
      continue;
    }

    final manifestFile = File('${entity.path}/manifest.json');

    if (!manifestFile.existsSync()) {
      continue;
    }

    manuals.add(_readManual(entity, manifestFile));
  }

  manuals.sort((left, right) => left.id.compareTo(right.id));

  return manuals;
}

String discoverLibraryCatalogJson(
  Directory assetRoot,
  List<GeneratedManual> manuals,
) {
  final catalogFile = File('${assetRoot.path}/library_catalog.json');
  if (catalogFile.existsSync()) {
    final rawJson = catalogFile.readAsStringSync();
    final decoded = _decodeLibraryCatalog(rawJson);
    _validateLibraryCatalogAgainstManuals(decoded, manuals);
    return jsonEncode(decoded);
  }

  final legacyCollectionsFile = File('${assetRoot.path}/collections.json');
  if (legacyCollectionsFile.existsSync()) {
    final library = discoverLibraryEntries(assetRoot, manuals);
    final catalogJson = _legacyLibraryToCatalogJson(library);
    final catalog = _decodeLibraryCatalog(catalogJson);
    _validateLibraryCatalogAgainstManuals(catalog, manuals);
    return catalogJson;
  }

  final flatCatalog = {
    'schemaVersion': _libraryCatalogSchemaVersion,
    'catalogVersion': 'generated',
    'entries': [
      for (final manual in manuals)
        {
          'type': 'manual',
          'manualId': manual.id,
          'title': {'en': manual.title},
          if (manual.subtitle != null) 'subtitle': {'en': manual.subtitle!},
        },
    ],
  };
  return jsonEncode(flatCatalog);
}

void _validateLibraryCatalogAgainstManuals(
  Map<String, Object?> catalog,
  List<GeneratedManual> manuals,
) {
  final manualIds = {for (final manual in manuals) manual.id};
  final referenced = <String>{};
  for (final manualId in _catalogManualIds(catalog)) {
    if (!manualIds.contains(manualId)) {
      throw FormatException(
        'Library Catalog referencia un manual inexistente: $manualId',
      );
    }
    if (!referenced.add(manualId)) {
      throw FormatException(
        'Library Catalog referencia dos veces el manual: $manualId',
      );
    }
  }
}

Map<String, Object?> _decodeLibraryCatalog(String source) {
  if (utf8.encode(source).length > _maxCatalogJsonBytes) {
    throw const FormatException('Library Catalog demasiado grande.');
  }
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Library Catalog raíz inválido.');
  }
  if (decoded['schemaVersion'] != _libraryCatalogSchemaVersion) {
    throw const FormatException('Library Catalog schemaVersion inválido.');
  }
  if (_string(decoded['catalogVersion']) == null) {
    throw const FormatException('Library Catalog catalogVersion inválido.');
  }
  _validateOptionalString(decoded, 'defaultLanguage', 'catalog');
  _validateOptionalString(decoded, 'generatedAt', 'catalog');
  _validateMetadata(decoded, 'catalog');
  final entries = decoded['entries'];
  if (entries is! List) {
    throw const FormatException('Library Catalog entries debe ser una lista.');
  }
  if (entries.length > _maxCatalogEntriesPerList) {
    throw const FormatException(
      'Library Catalog contiene demasiadas entradas.',
    );
  }
  final collectionIds = <String>{};
  for (var index = 0; index < entries.length; index += 1) {
    _validateCatalogEntryShape(
      entries[index],
      'entries[$index]',
      depth: 0,
      collectionIds: collectionIds,
    );
  }
  return decoded;
}

Iterable<String> _catalogManualIds(Map<String, Object?> catalog) sync* {
  final entries = catalog['entries'];
  if (entries is! List) return;
  for (final entry in entries) {
    yield* _catalogEntryManualIds(entry);
  }
}

Iterable<String> _catalogEntryManualIds(Object? entry) sync* {
  if (entry is! Map<String, Object?>) return;
  switch (entry['type']) {
    case 'manual':
      final manualId = _string(entry['manualId']);
      if (manualId != null) yield manualId;
    case 'collection':
      final children = entry['children'];
      if (children is List) {
        for (final child in children) {
          yield* _catalogEntryManualIds(child);
        }
      }
  }
}

void _validateCatalogEntryShape(
  Object? entry,
  String path, {
  required int depth,
  required Set<String> collectionIds,
}) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('Entrada inválida en $path.');
  }
  if (depth > _maxCatalogDepth) {
    throw FormatException('Library Catalog demasiado profundo en $path.');
  }
  _validateGroups(entry, path);
  _validateOptionalBool(entry, 'visible', path);
  _validateOptionalBool(entry, 'featured', path);
  _validateOptionalLocalized(entry, 'title', path);
  _validateOptionalLocalized(entry, 'subtitle', path);
  _validateOptionalLocalized(entry, 'description', path);
  _validateMaterialIcon(entry, 'icon', path);
  _validateAssetPath(entry, 'image', path);
  _validateBadges(entry, path);
  _validateMetadata(entry, path);
  switch (entry['type']) {
    case 'manual':
      final manualId = _string(entry['manualId']);
      if (manualId == null || !_safeIdentifier.hasMatch(manualId)) {
        throw FormatException('manualId inválido en $path.');
      }
      if (entry.containsKey('deploymentPolicy')) {
        throw FormatException(
          'deploymentPolicy no pertenece a Library Catalog en $path.',
        );
      }
    case 'collection':
      final id = _string(entry['id']);
      if (id == null || !_safeIdentifier.hasMatch(id)) {
        throw FormatException('id de colección inválido en $path.');
      }
      if (!collectionIds.add(id)) {
        throw FormatException('id de colección duplicado en $path: $id.');
      }
      final title = entry['title'];
      if (title is! Map<String, Object?> || title.isEmpty) {
        throw FormatException('title localizado inválido en $path.');
      }
      final children = entry['children'];
      if (children is! List) {
        throw FormatException('children inválido en $path.');
      }
      if (children.length > _maxCatalogEntriesPerList) {
        throw FormatException('Demasiadas entradas en $path.children.');
      }
      for (var index = 0; index < children.length; index += 1) {
        _validateCatalogEntryShape(
          children[index],
          '$path.children[$index]',
          depth: depth + 1,
          collectionIds: collectionIds,
        );
      }
    default:
      throw FormatException('type inválido en $path.');
  }
}

void _validateOptionalString(
  Map<String, Object?> entry,
  String key,
  String path,
) {
  if (!entry.containsKey(key) || entry[key] == null) return;
  final value = entry[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key inválido en $path.');
  }
}

void _validateOptionalBool(
  Map<String, Object?> entry,
  String key,
  String path,
) {
  if (!entry.containsKey(key) || entry[key] == null) return;
  if (entry[key] is! bool) {
    throw FormatException('$key inválido en $path.');
  }
}

void _validateOptionalLocalized(
  Map<String, Object?> entry,
  String key,
  String path,
) {
  if (!entry.containsKey(key) || entry[key] == null) return;
  _validateLocalized(entry[key], '$path.$key');
}

void _validateLocalized(Object? value, String path) {
  if (value is! Map<String, Object?> || value.isEmpty) {
    throw FormatException('Texto localizado inválido en $path.');
  }
  if (value.length > _maxLocalizedValues) {
    throw FormatException('Demasiadas traducciones en $path.');
  }
  for (final entry in value.entries) {
    if (entry.key.isEmpty || entry.value is! String || entry.value == '') {
      throw FormatException('Texto localizado inválido en $path.');
    }
  }
}

void _validateGroups(Map<String, Object?> entry, String path) {
  final value = entry['groups'];
  if (value == null) return;
  if (value is! List ||
      !value.every((group) => group is String && group.isNotEmpty)) {
    throw FormatException('groups inválido en $path.');
  }
  if (value.toSet().length != value.length) {
    throw FormatException('groups duplicados en $path.');
  }
}

void _validateAssetPath(Map<String, Object?> entry, String key, String path) {
  if (!entry.containsKey(key) || entry[key] == null) return;
  final value = entry[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key inválido en $path.');
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    throw FormatException('$key debe ser un asset local en $path.');
  }
  if (value.startsWith('/') || value.contains('\\')) {
    throw FormatException('$key debe ser una ruta relativa segura en $path.');
  }
  final segments = value.split('/');
  if (segments.any((segment) => segment.isEmpty || segment == '..')) {
    throw FormatException('$key debe ser una ruta relativa segura en $path.');
  }
}

void _validateMaterialIcon(Map<String, Object?> entry, String key, String path) {
  if (!entry.containsKey(key) || entry[key] == null) return;
  final value = entry[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key inválido en $path.');
  }
  if (OmniMaterialIcons.normalize(value) == null) {
    throw FormatException(
      "El icono '$value' no pertenece al catálogo Material soportado en $path.",
    );
  }
}

void _validateBadges(Map<String, Object?> entry, String path) {
  final badges = entry['badges'];
  if (badges == null) return;
  if (badges is! List) {
    throw FormatException('badges inválido en $path.');
  }
  if (badges.length > _maxBadges) {
    throw FormatException('Demasiados badges en $path.');
  }
  for (var index = 0; index < badges.length; index += 1) {
    final badge = badges[index];
    final badgePath = '$path.badges[$index]';
    if (badge is! Map<String, Object?>) {
      throw FormatException('badge inválido en $badgePath.');
    }
    final id = _string(badge['id']);
    if (id == null || !_safeIdentifier.hasMatch(id)) {
      throw FormatException('id de badge inválido en $badgePath.');
    }
    _validateLocalized(badge['label'], '$badgePath.label');
    _validateOptionalString(badge, 'tone', badgePath);
  }
}

void _validateMetadata(Map<String, Object?> entry, String path) {
  final metadata = entry['metadata'];
  if (metadata == null) return;
  if (metadata is! Map<String, Object?>) {
    throw FormatException('metadata inválido en $path.');
  }
  if (metadata.length > _maxMetadataKeys) {
    throw FormatException('metadata demasiado grande en $path.');
  }
}

int _countCatalogCollections(Map<String, Object?> catalog) {
  var count = 0;
  void visit(Object? entry) {
    if (entry is! Map<String, Object?>) return;
    switch (entry['type']) {
      case 'manual':
        return;
      case 'collection':
        count += 1;
        final children = entry['children'];
        if (children is List) {
          for (final child in children) {
            visit(child);
          }
        }
    }
  }

  final entries = catalog['entries'];
  if (entries is List) {
    for (final entry in entries) {
      visit(entry);
    }
  }
  return count;
}

String _legacyLibraryToCatalogJson(GeneratedLibrary library) {
  return jsonEncode({
    'schemaVersion': _libraryCatalogSchemaVersion,
    'catalogVersion': 'generated-from-collections',
    'entries': [
      for (final entry in library.entries) _legacyEntryToCatalogJson(entry),
    ],
  });
}

Map<String, Object?> _legacyEntryToCatalogJson(GeneratedLibraryEntry entry) {
  return switch (entry) {
    GeneratedManualLibraryEntry(:final manual) => {
      'type': 'manual',
      'manualId': manual.id,
      'title': {'en': manual.title},
      if (manual.subtitle != null) 'subtitle': {'en': manual.subtitle!},
    },
    GeneratedCollectionLibraryEntry(
      :final id,
      :final title,
      :final subtitle,
      :final children,
    ) =>
      {
        'type': 'collection',
        'id': id,
        'title': {'en': title},
        if (subtitle != null) 'subtitle': {'en': subtitle},
        'children': [
          for (final child in children) _legacyEntryToCatalogJson(child),
        ],
      },
  };
}

GeneratedLibrary discoverLibraryEntries(
  Directory assetRoot,
  List<GeneratedManual> manuals,
) {
  final collectionsFile = File('${assetRoot.path}/collections.json');
  if (!collectionsFile.existsSync()) {
    return GeneratedLibrary(
      entries: [
        for (final manual in manuals) GeneratedManualLibraryEntry(manual),
      ],
      collectionCount: 0,
    );
  }

  final manualById = <String, GeneratedManual>{
    for (final manual in manuals) manual.id: manual,
  };
  final referencedManualIds = <String>{};
  final collectionIds = <String>{};
  final root = _readJson(collectionsFile);
  final collections = root['collections'];

  if (collections is! List) {
    throw FormatException(
      'collections.json debe contener una lista raíz "collections".',
      collectionsFile.path,
    );
  }

  var collectionCount = 0;
  final entries = <GeneratedLibraryEntry>[
    for (final collection in collections)
      _readCollectionEntry(
        collection,
        manualById: manualById,
        referencedManualIds: referencedManualIds,
        collectionIds: collectionIds,
        collectionCount: () => collectionCount += 1,
        path: 'collections',
      ),
  ];

  for (final manual in manuals) {
    if (!referencedManualIds.contains(manual.id)) {
      entries.add(GeneratedManualLibraryEntry(manual));
    }
  }

  return GeneratedLibrary(entries: entries, collectionCount: collectionCount);
}

GeneratedCollectionLibraryEntry _readCollectionEntry(
  Object? raw, {
  required Map<String, GeneratedManual> manualById,
  required Set<String> referencedManualIds,
  required Set<String> collectionIds,
  required int Function() collectionCount,
  required String path,
}) {
  if (raw is! Map<String, Object?>) {
    throw FormatException('Colección inválida en $path.');
  }

  final id = _string(raw['id']);
  final title = _string(raw['title']);
  if (id == null || id.isEmpty) {
    throw FormatException('Colección sin id válido en $path.');
  }
  if (title == null || title.isEmpty) {
    throw FormatException('Colección "$id" sin title válido.');
  }
  if (!collectionIds.add(id)) {
    throw FormatException('ID de colección duplicado: $id.');
  }
  collectionCount();

  final children = <GeneratedLibraryEntry>[];
  final manualIds = raw['manuals'];
  if (manualIds != null && manualIds is! List) {
    throw FormatException('Colección "$id": manuals debe ser una lista.');
  }

  for (final manualId in manualIds is List ? manualIds : const <Object?>[]) {
    if (manualId is! String || manualId.isEmpty) {
      throw FormatException('Colección "$id": manual ID inválido.');
    }
    final manual = manualById[manualId];
    if (manual == null) {
      throw FormatException(
        'Colección "$id" referencia un manual inexistente: $manualId.',
      );
    }
    if (!referencedManualIds.add(manualId)) {
      throw FormatException(
        'Manual "$manualId" asignado a más de una colección.',
      );
    }
    children.add(GeneratedManualLibraryEntry(manual));
  }

  final nestedCollections = raw['children'];
  if (nestedCollections != null && nestedCollections is! List) {
    throw FormatException('Colección "$id": children debe ser una lista.');
  }

  for (final child
      in nestedCollections is List ? nestedCollections : const <Object?>[]) {
    children.add(
      _readCollectionEntry(
        child,
        manualById: manualById,
        referencedManualIds: referencedManualIds,
        collectionIds: collectionIds,
        collectionCount: collectionCount,
        path: '$path/$id/children',
      ),
    );
  }

  return GeneratedCollectionLibraryEntry(
    id: id,
    title: title,
    subtitle: _string(raw['subtitle']),
    children: children,
  );
}

List<String> discoverAssetDirectories(Directory assetRoot) {
  final manualsRoot = Directory('${assetRoot.path}/manuals');

  if (!manualsRoot.existsSync()) {
    throw FileSystemException(
      'No existe el directorio de manuales',
      manualsRoot.path,
    );
  }

  final normalizedManualsRoot = _normalizePath(manualsRoot.path);
  final directories = <String>{};

  for (final entity in manualsRoot.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }

    final normalizedFilePath = _normalizePath(entity.path);

    if (_shouldIgnoreAssetPath(
      normalizedFilePath,
      rootPath: normalizedManualsRoot,
    )) {
      continue;
    }

    final normalizedDirectoryPath = _normalizePath(entity.parent.path);

    directories.add(
      normalizedDirectoryPath.endsWith('/')
          ? normalizedDirectoryPath
          : '$normalizedDirectoryPath/',
    );
  }

  final sortedDirectories = directories.toList()..sort();
  return sortedDirectories;
}

void synchronizePubspecAssets({
  required File pubspecFile,
  required String assetRoot,
  required List<String> assetDirectories,
}) {
  const beginMarker = '    # >>> OMNI MANUALS GENERATED - DO NOT EDIT >>>';
  const endMarker = '    # <<< OMNI MANUALS GENERATED <<<';

  final normalizedAssetRoot = _normalizePath(assetRoot);
  final original = pubspecFile.readAsStringSync();
  final newline = original.contains('\r\n') ? '\r\n' : '\n';

  var lines = original
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');

  lines = _removeGeneratedBlock(lines, beginMarker.trim(), endMarker.trim());
  lines = _removeGeneratedBlock(
    lines,
    '# BEGIN OMNIMANUAL GENERATED ASSETS',
    '# END OMNIMANUAL GENERATED ASSETS',
  );

  lines = lines.where((line) {
    final trimmed = line.trim();

    if (!trimmed.startsWith('- ')) {
      return true;
    }

    final value = trimmed.substring(2).trim();
    final normalizedValue = _normalizePath(value);

    if (normalizedValue == normalizedAssetRoot ||
        assetDirectories.contains(normalizedValue)) {
      return false;
    }

    return !_isLegacyRuntimeOrLibraryAsset(normalizedValue);
  }).toList();

  final flutterIndex = _findTopLevelKey(lines, 'flutter:');

  if (flutterIndex == -1) {
    throw const FormatException(
      'El pubspec.yaml no contiene una sección flutter:.',
    );
  }

  final flutterEnd = _findTopLevelSectionEnd(lines, flutterIndex + 1);

  var assetsIndex = -1;

  for (var index = flutterIndex + 1; index < flutterEnd; index += 1) {
    if (lines[index].trim() == 'assets:') {
      assetsIndex = index;
      break;
    }
  }

  final generatedLines = <String>[
    beginMarker,
    for (final directory in assetDirectories)
      '    - ${_normalizePath(directory)}',
    endMarker,
  ];

  if (assetsIndex == -1) {
    final insertion = <String>['  assets:', ...generatedLines];

    lines.insertAll(flutterEnd, insertion);
  } else {
    lines.insertAll(assetsIndex + 1, generatedLines);
  }

  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  final result = '${lines.join(newline)}$newline';
  pubspecFile.writeAsStringSync(result);
}

List<String> _removeGeneratedBlock(
  List<String> lines,
  String beginMarker,
  String endMarker,
) {
  final result = <String>[];
  var insideGeneratedBlock = false;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed == beginMarker) {
      insideGeneratedBlock = true;
      continue;
    }

    if (trimmed == endMarker) {
      insideGeneratedBlock = false;
      continue;
    }

    if (!insideGeneratedBlock) {
      result.add(line);
    }
  }

  if (insideGeneratedBlock) {
    throw const FormatException(
      'El bloque generado de Omni Manuals en pubspec.yaml '
      'no está correctamente cerrado.',
    );
  }

  return result;
}

int _findTopLevelKey(List<String> lines, String key) {
  for (var index = 0; index < lines.length; index += 1) {
    if (lines[index] == key) {
      return index;
    }
  }

  return -1;
}

int _findTopLevelSectionEnd(List<String> lines, int startIndex) {
  for (var index = startIndex; index < lines.length; index += 1) {
    final line = lines[index];

    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      continue;
    }

    final hasTopLevelIndentation =
        line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t');

    if (hasTopLevelIndentation) {
      return index;
    }
  }

  return lines.length;
}

String renderRegistry({
  required String className,
  required String assetRoot,
  required List<GeneratedManual> manuals,
  required String libraryCatalogJson,
}) {
  final normalizedAssetRoot = _normalizePath(assetRoot);
  final catalogClassName = className.endsWith('Source')
      ? '${className.substring(0, className.length - 'Source'.length)}CatalogSource'
      : '${className}CatalogSource';
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Generated by package:omni_manuals.')
    ..writeln()
    ..writeln("import 'package:flutter/foundation.dart';")
    ..writeln("import 'package:flutter/services.dart' show rootBundle;")
    ..writeln("import 'package:omni_manuals/omni_manuals.dart';")
    ..writeln()
    ..writeln('final class $className extends OmniManualsSource {')
    ..writeln('  const $className();')
    ..writeln()
    ..writeln(
      '  static const String _assetRoot = ${_dartString(normalizedAssetRoot)};',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[',
    );

  for (final manual in manuals) {
    buffer
      ..writeln('    OmniManualInfo(')
      ..writeln('      id: ${_dartString(manual.id)},')
      ..writeln('      title: ${_dartString(manual.title)},');

    if (manual.subtitle != null) {
      buffer.writeln('      subtitle: ${_dartString(manual.subtitle!)},');
    }

    if (manual.version != null) {
      buffer.writeln('      version: ${_dartString(manual.version!)},');
    }

    if (manual.minimumRuntimeVersion != null) {
      buffer.writeln(
        '      minimumRuntimeVersion: '
        '${_dartString(manual.minimumRuntimeVersion!)},',
      );
    }

    if (manual.languages.isNotEmpty) {
      buffer
        ..write('      languages: <String>[')
        ..write(manual.languages.map(_dartString).join(', '))
        ..writeln('],');
    }

    buffer.writeln('    ),');
  }

  buffer
    ..writeln('  ];')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Future<Uint8List?> loadAsset(String relativePath) async {')
    ..writeln('    if (!_isSafeOmniManualAssetPath(relativePath)) return null;')
    ..writeln("    final assetKey = '\$_assetRoot/\$relativePath';")
    ..writeln('    try {')
    ..writeln('      final data = await rootBundle.load(assetKey);')
    ..writeln(
      '      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);',
    )
    ..writeln('    } on FlutterError {')
    ..writeln('      return null;')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('bool _isSafeOmniManualAssetPath(String path) {')
    ..writeln("  if (!path.startsWith('manuals/')) return false;")
    ..writeln(
      "  if (path.isEmpty || path.contains('\\\\') || path.contains('//')) {",
    )
    ..writeln('    return false;')
    ..writeln('  }')
    ..writeln("  final parts = path.split('/');")
    ..writeln(
      "  return !parts.any((part) => part.isEmpty || part == '.' || part == '..');",
    )
    ..writeln('}')
    ..writeln()
    ..writeln(
      'final class $catalogClassName extends OmniLibraryCatalogSource {',
    )
    ..writeln('  const $catalogClassName();')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Future<OmniLibraryCatalog?> loadCatalog() async =>')
    ..writeln(
      '      OmniLibraryCatalog.parse(_generatedOmniLibraryCatalogJson);',
    )
    ..writeln('}')
    ..writeln()
    ..writeln("const String _generatedOmniLibraryCatalogJson = r'''")
    ..writeln(libraryCatalogJson)
    ..writeln("''';");

  return buffer.toString();
}

GeneratedManual _readManual(Directory manualDirectory, File manifestFile) {
  final manifest = _readJson(manifestFile);
  final id = _string(manifest['id']) ?? _basename(manualDirectory.path);

  final entrypoint = _string(manifest['entrypoint']) ?? 'manual.json';

  final manualFile = File('${manualDirectory.path}/$entrypoint');

  final manual = manualFile.existsSync()
      ? _readJson(manualFile)
      : <String, Object?>{};

  final languages = _strings(manual['languages']);

  final defaultLanguage =
      _string(manual['defaultLanguage']) ??
      (languages.isEmpty ? null : languages.first);

  final content = defaultLanguage == null
      ? <String, Object?>{}
      : _readContent(manualDirectory, manual, defaultLanguage);

  final metadata = manual['metadata'] is Map<String, Object?>
      ? manual['metadata'] as Map<String, Object?>
      : <String, Object?>{};

  final titleKey = _string(metadata['titleKey']);
  final subtitleKey = _string(metadata['subtitleKey']);

  return GeneratedManual(
    id: id,
    title: titleKey == null ? id : (_lookup(content, titleKey) ?? id),
    subtitle: subtitleKey == null ? null : _lookup(content, subtitleKey),
    version: _string(manifest['version']),
    minimumRuntimeVersion: _string(manifest['minimumRuntimeVersion']),
    languages: languages,
  );
}

Map<String, Object?> _readContent(
  Directory manualDirectory,
  Map<String, Object?> manual,
  String language,
) {
  final contentMap = manual['content'];

  if (contentMap is! Map<String, Object?>) {
    return <String, Object?>{};
  }

  final path = _string(contentMap[language]);

  if (path == null) {
    return <String, Object?>{};
  }

  final file = File('${manualDirectory.path}/$path');

  if (!file.existsSync()) {
    return <String, Object?>{};
  }

  return _readJson(file);
}

Map<String, Object?> _readJson(File file) {
  final decoded = jsonDecode(file.readAsStringSync());

  if (decoded is Map<String, Object?>) {
    return decoded;
  }

  throw FormatException('JSON raíz inválido en ${file.path}');
}

String? _lookup(Map<String, Object?> values, String dottedKey) {
  Object? current = values;

  for (final part in dottedKey.split('.')) {
    if (current is! Map<String, Object?>) {
      return null;
    }

    current = current[part];
  }

  return current is String && current.isNotEmpty ? current : null;
}

String _basename(String path) =>
    Uri.file(path).pathSegments.where((segment) => segment.isNotEmpty).last;

String _normalizePath(String path) {
  return path.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');
}

bool _shouldIgnoreAssetPath(String path, {required String rootPath}) {
  final normalizedPath = _normalizePath(path);
  final normalizedRoot = _normalizePath(rootPath);

  final relativePath = normalizedPath == normalizedRoot
      ? ''
      : normalizedPath.startsWith('$normalizedRoot/')
      ? normalizedPath.substring(normalizedRoot.length + 1)
      : normalizedPath;

  final segments = relativePath
      .split('/')
      .where((segment) => segment.isNotEmpty);

  for (final segment in segments) {
    if (_shouldIgnoreAssetSegment(segment)) {
      return true;
    }
  }

  return false;
}

bool _shouldIgnoreAssetSegment(String segment) {
  if (segment.startsWith('.')) {
    return true;
  }

  switch (segment) {
    case '__MACOSX':
    case 'node_modules':
    case 'build':
    case '.dart_tool':
    case '.git':
    case '.svn':
    case '.idea':
    case '.vscode':
      return true;
  }

  return false;
}

bool _isLegacyRuntimeOrLibraryAsset(String normalizedValue) {
  const legacyRoot = 'assets/omnimanual';
  if (normalizedValue == legacyRoot || normalizedValue == '$legacyRoot/') {
    return true;
  }
  return normalizedValue == '$legacyRoot/runtime' ||
      normalizedValue == '$legacyRoot/runtime/' ||
      normalizedValue.startsWith('$legacyRoot/runtime/') ||
      normalizedValue == '$legacyRoot/library' ||
      normalizedValue == '$legacyRoot/library/' ||
      normalizedValue.startsWith('$legacyRoot/library/') ||
      normalizedValue == '$legacyRoot/viewer-config.json';
}

String? _string(Object? value) {
  return value is String ? value : null;
}

List<String> _strings(Object? value) {
  return value is List
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];
}

String _dartString(String value) => jsonEncode(value);

final class GeneratedManual {
  const GeneratedManual({
    required this.id,
    required this.title,
    required this.languages,
    this.subtitle,
    this.version,
    this.minimumRuntimeVersion,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? version;
  final String? minimumRuntimeVersion;
  final List<String> languages;
}

final class GeneratedLibrary {
  const GeneratedLibrary({
    required this.entries,
    required this.collectionCount,
  });

  final List<GeneratedLibraryEntry> entries;
  final int collectionCount;
}

sealed class GeneratedLibraryEntry {
  const GeneratedLibraryEntry();
}

final class GeneratedManualLibraryEntry extends GeneratedLibraryEntry {
  const GeneratedManualLibraryEntry(this.manual);

  final GeneratedManual manual;
}

final class GeneratedCollectionLibraryEntry extends GeneratedLibraryEntry {
  const GeneratedCollectionLibraryEntry({
    required this.id,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<GeneratedLibraryEntry> children;
}
