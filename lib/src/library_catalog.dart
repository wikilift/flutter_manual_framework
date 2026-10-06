import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'material_icon_catalog.dart';
import 'models.dart';
import 'internal/localization.dart';

const int omniLibraryCatalogSchemaVersion = 1;
const int _maxCatalogJsonBytes = 1024 * 1024;
const int _maxCatalogDepth = 16;
const int _maxCatalogEntriesPerList = 1000;
const int _maxLocalizedValues = 32;
const int _maxBadges = 32;
const int _maxMetadataKeys = 64;

typedef OmniTokenProvider = Future<String?> Function();
final RegExp _safeCatalogId = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

final class OmniLocalizedText {
  const OmniLocalizedText(this.values);

  factory OmniLocalizedText.fromJson(Object? value, String path) {
    if (value is! Map<String, Object?> || value.isEmpty) {
      throw FormatException('Texto localizado inválido: $path');
    }
    if (value.length > _maxLocalizedValues) {
      throw FormatException('Demasiadas traducciones en $path');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final language = entry.key;
      final text = entry.value;
      if (language.isEmpty || text is! String || text.isEmpty) {
        throw FormatException('Texto localizado inválido: $path.$language');
      }
      result[language] = text;
    }
    return OmniLocalizedText(Map<String, String>.unmodifiable(result));
  }

  final Map<String, String> values;

  String resolve(
    String? language, {
    String? defaultLanguage,
    String fallback = '',
  }) =>
      resolveLocalizedText(
        values,
        language,
        defaultLanguage: defaultLanguage,
      ) ??
      fallback;

  Map<String, Object?> toJson() => values;
}

final class OmniLibraryBadge {
  const OmniLibraryBadge({required this.id, required this.label, this.tone});

  factory OmniLibraryBadge.fromJson(Object? value, String path) {
    final json = _object(value, path);
    final id = _requiredId(json, 'id', path);
    return OmniLibraryBadge(
      id: id,
      label: OmniLocalizedText.fromJson(json['label'], '$path.label'),
      tone: _optionalString(json, 'tone'),
    );
  }

  final String id;
  final OmniLocalizedText label;
  final String? tone;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label.toJson(),
    if (tone != null) 'tone': tone,
  };
}

sealed class OmniLibraryCatalogEntry {
  const OmniLibraryCatalogEntry({
    required this.id,
    this.title,
    this.subtitle,
    this.description,
    this.icon,
    this.image,
    this.badges = const <OmniLibraryBadge>[],
    this.featured = false,
    this.groups = const <String>{},
    this.visible = true,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final OmniLocalizedText? title;
  final OmniLocalizedText? subtitle;
  final OmniLocalizedText? description;
  final String? icon;
  final String? image;
  final List<OmniLibraryBadge> badges;
  final bool featured;
  final Set<String> groups;
  final bool visible;
  final Map<String, Object?> metadata;

  bool visibleFor(Set<String> userGroups) {
    if (!visible) return false;
    if (groups.isEmpty) return true;
    return groups.any(userGroups.contains);
  }

  Map<String, Object?> _baseJson(String type) => {
    'type': type,
    'id': id,
    if (title != null) 'title': title!.toJson(),
    if (subtitle != null) 'subtitle': subtitle!.toJson(),
    if (description != null) 'description': description!.toJson(),
    if (icon != null) 'icon': icon,
    if (image != null) 'image': image,
    if (badges.isNotEmpty)
      'badges': [for (final badge in badges) badge.toJson()],
    if (featured) 'featured': featured,
    if (groups.isNotEmpty) 'groups': groups.toList()..sort(),
    if (!visible) 'visible': visible,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

final class OmniLibraryCatalogManual extends OmniLibraryCatalogEntry {
  const OmniLibraryCatalogManual({
    required super.id,
    required this.manualId,
    super.title,
    super.subtitle,
    super.description,
    super.icon,
    super.image,
    super.badges,
    super.featured,
    super.groups,
    super.visible,
    super.metadata,
  });

  factory OmniLibraryCatalogManual.fromJson(
    Map<String, Object?> json,
    String path,
  ) {
    if (json.containsKey('deploymentPolicy')) {
      throw FormatException(
        'deploymentPolicy no pertenece a Library Catalog: $path',
      );
    }
    return OmniLibraryCatalogManual(
      id: _optionalId(json, 'id', path) ?? _requiredId(json, 'manualId', path),
      manualId: _requiredId(json, 'manualId', path),
      title: _optionalLocalized(json, 'title', path),
      subtitle: _optionalLocalized(json, 'subtitle', path),
      description: _optionalLocalized(json, 'description', path),
      icon: _optionalMaterialIconName(json, 'icon', path),
      image: _optionalAssetPath(json, 'image', path),
      badges: _badges(json, path),
      featured: _optionalBool(json, 'featured') ?? false,
      groups: _groups(json, path),
      visible: _optionalBool(json, 'visible') ?? true,
      metadata: _metadata(json, path),
    );
  }

  final String manualId;

  Map<String, Object?> toJson() => {
    ..._baseJson('manual'),
    'manualId': manualId,
  };
}

final class OmniLibraryCatalogCollection extends OmniLibraryCatalogEntry {
  const OmniLibraryCatalogCollection({
    required super.id,
    required super.title,
    required this.children,
    super.subtitle,
    super.description,
    super.icon,
    super.image,
    super.badges,
    super.featured,
    super.groups,
    super.visible,
    super.metadata,
  });

  factory OmniLibraryCatalogCollection.fromJson(
    Map<String, Object?> json,
    String path,
    int depth,
  ) {
    return OmniLibraryCatalogCollection(
      id: _requiredId(json, 'id', path),
      title: OmniLocalizedText.fromJson(json['title'], '$path.title'),
      subtitle: _optionalLocalized(json, 'subtitle', path),
      description: _optionalLocalized(json, 'description', path),
      icon: _optionalMaterialIconName(json, 'icon', path),
      image: _optionalAssetPath(json, 'image', path),
      badges: _badges(json, path),
      featured: _optionalBool(json, 'featured') ?? false,
      groups: _groups(json, path),
      visible: _optionalBool(json, 'visible') ?? true,
      metadata: _metadata(json, path),
      children: _entries(json['children'], '$path.children', depth: depth + 1),
    );
  }

  final List<OmniLibraryCatalogEntry> children;

  Map<String, Object?> toJson() => {
    ..._baseJson('collection'),
    'children': [for (final child in children) _entryToJson(child)],
  };
}

final class OmniLibraryCatalog {
  const OmniLibraryCatalog({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.entries,
    this.defaultLanguage,
    this.generatedAt,
    this.metadata = const <String, Object?>{},
  });

  factory OmniLibraryCatalog.parse(String source) {
    if (utf8.encode(source).length > _maxCatalogJsonBytes) {
      throw const FormatException('Library Catalog demasiado grande.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'El Library Catalog debe ser un objeto JSON.',
      );
    }
    return OmniLibraryCatalog.fromJson(decoded);
  }

  factory OmniLibraryCatalog.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredPositiveInt(json, 'schemaVersion');
    if (schemaVersion != omniLibraryCatalogSchemaVersion) {
      throw FormatException('schemaVersion no soportado: $schemaVersion');
    }
    return OmniLibraryCatalog(
      schemaVersion: schemaVersion,
      catalogVersion: _requiredString(json, 'catalogVersion'),
      defaultLanguage: _optionalString(json, 'defaultLanguage'),
      generatedAt: _optionalDateTime(json, 'generatedAt'),
      metadata: _metadata(json, 'catalog'),
      entries: _entries(json['entries'], 'entries', depth: 0),
    );
  }

  final int schemaVersion;
  final String catalogVersion;
  final String? defaultLanguage;
  final DateTime? generatedAt;
  final List<OmniLibraryCatalogEntry> entries;
  final Map<String, Object?> metadata;

  List<String> get manualIds {
    final ids = <String>[];
    void visit(OmniLibraryCatalogEntry entry) {
      switch (entry) {
        case OmniLibraryCatalogManual(:final manualId):
          ids.add(manualId);
        case OmniLibraryCatalogCollection(:final children):
          for (final child in children) {
            visit(child);
          }
      }
    }

    for (final entry in entries) {
      visit(entry);
    }
    return List<String>.unmodifiable(ids);
  }

  List<OmniLibraryEntry> toLibraryEntries({
    required List<OmniManualInfo> registry,
    required String? language,
    required Set<String> userGroups,
  }) {
    final manualById = {for (final manual in registry) manual.id: manual};
    final assignedManualIds = <String>{};
    final result = <OmniLibraryEntry>[];
    for (final entry in entries) {
      final converted = _toLibraryEntry(
        entry,
        manualById: manualById,
        assignedManualIds: assignedManualIds,
        language: language,
        defaultLanguage: defaultLanguage,
        userGroups: userGroups.isEmpty ? const {'default'} : userGroups,
      );
      if (converted != null) result.add(converted);
    }

    return List<OmniLibraryEntry>.unmodifiable(result);
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'catalogVersion': catalogVersion,
    if (defaultLanguage != null) 'defaultLanguage': defaultLanguage,
    if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
    'entries': [for (final entry in entries) _entryToJson(entry)],
  };
}

abstract class OmniLibraryCatalogSource {
  const OmniLibraryCatalogSource();

  Future<OmniLibraryCatalog?> loadCatalog();

  Future<void> refresh() async {}
}

final class OmniBundledCatalogSource extends OmniLibraryCatalogSource {
  const OmniBundledCatalogSource(this.catalog);

  final OmniLibraryCatalog catalog;

  @override
  Future<OmniLibraryCatalog?> loadCatalog() async => catalog;
}

typedef BundledCatalogSource = OmniBundledCatalogSource;

final class OmniRemoteCatalogSource extends OmniLibraryCatalogSource {
  const OmniRemoteCatalogSource({
    required this.endpoint,
    this.headers = const <String, String>{},
    this.tokenProvider,
    this.timeout = const Duration(seconds: 8),
    this.retryCount = 1,
  }) : assert(retryCount >= 0);

  final OmniTokenProvider? tokenProvider;

  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final int retryCount;

  @override
  Future<OmniLibraryCatalog?> loadCatalog() async {
    final response = await fetch();
    return response.catalog;
  }

  Future<OmniRemoteCatalogResponse> fetch({
    String? etag,
    String? lastModified,
  }) async {
    for (var attempt = 0; attempt <= retryCount; attempt += 1) {
      try {
        return await _fetchOnce(etag: etag, lastModified: lastModified);
      } on FormatException {
        rethrow;
      } catch (error, stackTrace) {
        if (attempt >= retryCount) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
    throw StateError('No se pudo descargar Library Catalog.');
  }

  Future<OmniRemoteCatalogResponse> _fetchOnce({
    String? etag,
    String? lastModified,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(endpoint).timeout(timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final token = await tokenProvider?.call();

      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (etag != null && etag.isNotEmpty) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      if (lastModified != null && lastModified.isNotEmpty) {
        request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode == HttpStatus.notModified) {
        return OmniRemoteCatalogResponse.notModified(
          etag: response.headers.value(HttpHeaders.etagHeader) ?? etag,
          lastModified:
              response.headers.value(HttpHeaders.lastModifiedHeader) ??
              lastModified,
        );
      }
      final body = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'No se pudo descargar Library Catalog: ${response.statusCode}',
          uri: endpoint,
        );
      }
      final catalog = OmniLibraryCatalog.parse(body);
      return OmniRemoteCatalogResponse(
        catalog: catalog,
        rawJson: body,
        etag: response.headers.value(HttpHeaders.etagHeader),
        lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
        notModified: false,
      );
    } finally {
      client.close(force: true);
    }
  }
}

typedef RemoteCatalogSource = OmniRemoteCatalogSource;

final class OmniRemoteCatalogResponse {
  const OmniRemoteCatalogResponse({
    required this.catalog,
    required this.rawJson,
    required this.etag,
    required this.lastModified,
    required this.notModified,
  });

  const OmniRemoteCatalogResponse.notModified({this.etag, this.lastModified})
    : catalog = null,
      rawJson = null,
      notModified = true;

  final OmniLibraryCatalog? catalog;
  final String? rawJson;
  final String? etag;
  final String? lastModified;
  final bool notModified;
}

final class OmniLibraryCatalogCache {
  const OmniLibraryCatalogCache({required this.root});

  static Future<OmniLibraryCatalogCache> defaultCache({Uri? endpoint}) async {
    final support = await getApplicationSupportDirectory();
    final endpointKey = endpoint == null
        ? 'bundled'
        : _endpointCacheKey(endpoint);
    return OmniLibraryCatalogCache(
      root: Directory(
        '${support.path}/omni_manuals/library_catalog/$endpointKey',
      ),
    );
  }

  final Directory root;

  File get jsonFile => File('${root.path}/library_catalog.json');
  File get metadataFile => File('${root.path}/library_catalog.meta.json');

  Future<OmniCachedLibraryCatalog?> load() async {
    if (!await jsonFile.exists()) return null;
    final rawJson = await jsonFile.readAsString();
    final catalog = OmniLibraryCatalog.parse(rawJson);
    final metadata = await _loadMetadata();
    return OmniCachedLibraryCatalog(
      catalog: catalog,
      rawJson: rawJson,
      etag: metadata['etag'] is String ? metadata['etag'] as String : null,
      lastModified: metadata['lastModified'] is String
          ? metadata['lastModified'] as String
          : null,
      catalogVersion: metadata['catalogVersion'] is String
          ? metadata['catalogVersion'] as String
          : catalog.catalogVersion,
      fetchedAt: metadata['fetchedAt'] is String
          ? DateTime.tryParse(metadata['fetchedAt'] as String)
          : null,
    );
  }

  Future<void> save({
    required String rawJson,
    required OmniLibraryCatalog catalog,
    String? etag,
    String? lastModified,
  }) async {
    OmniLibraryCatalog.parse(rawJson);
    await root.create(recursive: true);
    final nextJson = File('${jsonFile.path}.next');
    final nextMeta = File('${metadataFile.path}.next');
    await nextJson.writeAsString(rawJson, flush: true);
    final metadata = <String, Object?>{
      'catalogVersion': catalog.catalogVersion,
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (etag != null) metadata['etag'] = etag;
    if (lastModified != null) metadata['lastModified'] = lastModified;
    await nextMeta.writeAsString(jsonEncode(metadata), flush: true);
    if (await jsonFile.exists()) await jsonFile.delete();
    await nextJson.rename(jsonFile.path);
    if (await metadataFile.exists()) await metadataFile.delete();
    await nextMeta.rename(metadataFile.path);
  }

  Future<Map<String, Object?>> _loadMetadata() async {
    if (!await metadataFile.exists()) return const <String, Object?>{};
    final decoded = jsonDecode(await metadataFile.readAsString());
    return decoded is Map<String, Object?>
        ? decoded
        : const <String, Object?>{};
  }
}

final class OmniCachedLibraryCatalog {
  const OmniCachedLibraryCatalog({
    required this.catalog,
    required this.rawJson,
    this.etag,
    this.lastModified,
    this.catalogVersion,
    this.fetchedAt,
  });

  final OmniLibraryCatalog catalog;
  final String rawJson;
  final String? etag;
  final String? lastModified;
  final String? catalogVersion;
  final DateTime? fetchedAt;
}

final class OmniCachedCatalogSource extends OmniLibraryCatalogSource {
  OmniCachedCatalogSource({required this.remote, this.cache});

  final OmniRemoteCatalogSource remote;
  final OmniLibraryCatalogCache? cache;
  OmniLibraryCatalogCache? _resolvedCache;
  OmniLibraryCatalog? _memory;

  Future<OmniLibraryCatalogCache> _cache() async => _resolvedCache ??=
      cache ??
      await OmniLibraryCatalogCache.defaultCache(endpoint: remote.endpoint);

  @override
  Future<OmniLibraryCatalog?> loadCatalog() async {
    final resolved = await _cache();
    final cached = await _tryLoadCached(resolved);
    _memory = cached?.catalog ?? _memory;
    return _memory;
  }

  Future<bool> hasRemoteUpdate() async {
    final resolved = await _cache();
    final cached = await _tryLoadCached(resolved);
    try {
      final remoteResponse = await remote.fetch(
        etag: cached?.etag,
        lastModified: cached?.lastModified,
      );
      return !remoteResponse.notModified &&
          remoteResponse.catalog != null &&
          remoteResponse.rawJson != null &&
          (cached == null ||
              !_sameCatalog(cached.catalog, remoteResponse.catalog!));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> refresh() async {
    await refreshIfValid();
  }

  Future<bool> refreshIfValid({Set<String>? availableManualIds}) async {
    final resolved = await _cache();
    final cached = await _tryLoadCached(resolved);
    final remoteResponse = await remote.fetch(
      etag: cached?.etag,
      lastModified: cached?.lastModified,
    );
    if (remoteResponse.notModified) {
      _memory = cached?.catalog ?? _memory;
      return false;
    }
    final catalog = remoteResponse.catalog;
    final rawJson = remoteResponse.rawJson;
    if (catalog == null || rawJson == null) return false;
    final available = availableManualIds;
    if (available != null) {
      final missing = catalog.manualIds.where((id) => !available.contains(id));
      if (missing.isNotEmpty) {
        throw StateError(
          'Library Catalog remoto referencia paquetes no instalados: '
          '${missing.join(", ")}',
        );
      }
    }
    await resolved.save(
      rawJson: rawJson,
      catalog: catalog,
      etag: remoteResponse.etag,
      lastModified: remoteResponse.lastModified,
    );
    _memory = catalog;
    return cached == null || !_sameCatalog(cached.catalog, catalog);
  }

  Future<OmniCachedLibraryCatalog?> _tryLoadCached(
    OmniLibraryCatalogCache cache,
  ) async {
    try {
      return await cache.load();
    } catch (_) {
      return null;
    }
  }
}

typedef CachedCatalogSource = OmniCachedCatalogSource;

final class OmniFallbackCatalogSource extends OmniLibraryCatalogSource {
  const OmniFallbackCatalogSource(this.sources);

  final List<OmniLibraryCatalogSource> sources;

  @override
  Future<OmniLibraryCatalog?> loadCatalog() async {
    for (final source in sources) {
      try {
        final catalog = await source.loadCatalog();
        if (catalog != null) return catalog;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

typedef FallbackCatalogSource = OmniFallbackCatalogSource;

bool _sameCatalog(OmniLibraryCatalog left, OmniLibraryCatalog right) {
  Object? canonical(Object? value) {
    if (value is Map<String, Object?>) {
      return {
        for (final key in value.keys.toList()..sort())
          key: canonical(value[key]),
      };
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical(left.toJson())) ==
      jsonEncode(canonical(right.toJson()));
}

OmniLibraryEntry? _toLibraryEntry(
  OmniLibraryCatalogEntry entry, {
  required Map<String, OmniManualInfo> manualById,
  required Set<String> assignedManualIds,
  required String? language,
  required String? defaultLanguage,
  required Set<String> userGroups,
}) {
  if (!entry.visibleFor(userGroups)) return null;
  switch (entry) {
    case OmniLibraryCatalogManual(:final manualId):
      final manual = manualById[manualId];
      if (manual == null) return null;
      assignedManualIds.add(manualId);
      return OmniManualLibraryEntry(
        manual: manual,
        title: entry.title?.resolve(
          language,
          defaultLanguage: defaultLanguage,
          fallback: manual.title,
        ),
        subtitle: entry.subtitle?.resolve(
          language,
          defaultLanguage: defaultLanguage,
          fallback: manual.subtitle ?? '',
        ),
        description: entry.description?.resolve(
          language,
          defaultLanguage: defaultLanguage,
        ),
        icon: entry.icon ?? manual.icon,
        image: entry.image ?? manual.poster,
        badges: [
          for (final badge in entry.badges)
            badge.label.resolve(
              language,
              defaultLanguage: defaultLanguage,
              fallback: badge.id,
            ),
        ],
        featured: entry.featured,
        metadata: entry.metadata,
      );
    case OmniLibraryCatalogCollection(:final children):
      final convertedChildren = <OmniLibraryEntry>[];
      for (final child in children) {
        final converted = _toLibraryEntry(
          child,
          manualById: manualById,
          assignedManualIds: assignedManualIds,
          language: language,
          defaultLanguage: defaultLanguage,
          userGroups: userGroups,
        );
        if (converted != null) convertedChildren.add(converted);
      }
      return OmniCollectionEntry(
        id: entry.id,
        title:
            entry.title?.resolve(
              language,
              defaultLanguage: defaultLanguage,
              fallback: entry.id,
            ) ??
            entry.id,
        subtitle: entry.subtitle?.resolve(
          language,
          defaultLanguage: defaultLanguage,
        ),
        description: entry.description?.resolve(
          language,
          defaultLanguage: defaultLanguage,
        ),
        icon: entry.icon,
        image: entry.image,
        badges: [
          for (final badge in entry.badges)
            badge.label.resolve(
              language,
              defaultLanguage: defaultLanguage,
              fallback: badge.id,
            ),
        ],
        featured: entry.featured,
        metadata: entry.metadata,
        children: convertedChildren,
      );
  }
}

List<OmniLibraryCatalogEntry> _entries(
  Object? value,
  String path, {
  required int depth,
}) {
  if (value is! List) throw FormatException('Lista inválida: $path');
  if (depth > _maxCatalogDepth) {
    throw FormatException('Library Catalog demasiado profundo en $path');
  }
  if (value.length > _maxCatalogEntriesPerList) {
    throw FormatException('Demasiadas entradas en $path');
  }
  return List<OmniLibraryCatalogEntry>.unmodifiable([
    for (var index = 0; index < value.length; index += 1)
      _entryFromJson(value[index], '$path[$index]', depth: depth),
  ]);
}

OmniLibraryCatalogEntry _entryFromJson(
  Object? value,
  String path, {
  required int depth,
}) {
  final json = _object(value, path);
  final type = _requiredString(json, 'type');
  return switch (type) {
    'manual' => OmniLibraryCatalogManual.fromJson(json, path),
    'collection' => OmniLibraryCatalogCollection.fromJson(json, path, depth),
    _ => throw FormatException('Tipo de entrada inválido en $path: $type'),
  };
}

Map<String, Object?> _entryToJson(OmniLibraryCatalogEntry entry) {
  return switch (entry) {
    OmniLibraryCatalogManual() => entry.toJson(),
    OmniLibraryCatalogCollection() => entry.toJson(),
  };
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Objeto inválido: $path');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Campo obligatorio inválido: $key');
}

int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw FormatException('Campo obligatorio inválido: $key');
}

String _requiredId(Map<String, Object?> json, String key, String path) {
  final value = _requiredString(json, key);
  if (_safeCatalogId.hasMatch(value)) return value;
  throw FormatException('ID inválido en $path.$key: $value');
}

String? _optionalId(Map<String, Object?> json, String key, String path) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  if (_safeCatalogId.hasMatch(value)) return value;
  throw FormatException('ID inválido en $path.$key: $value');
}

String? _optionalString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Campo opcional inválido: $key');
}

bool? _optionalBool(Map<String, Object?> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Campo opcional inválido: $key');
}

String? _optionalAssetPath(Map<String, Object?> json, String key, String path) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    throw FormatException('$key debe ser un asset local en $path');
  }
  if (value.startsWith('/') || value.contains('\\')) {
    throw FormatException('$key debe ser una ruta relativa segura en $path');
  }
  final segments = value.split('/');
  if (segments.any((segment) => segment.isEmpty || segment == '..')) {
    throw FormatException('$key debe ser una ruta relativa segura en $path');
  }
  return value;
}

String? _optionalMaterialIconName(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final normalized = OmniMaterialIconCatalog.normalize(value);
  if (normalized == null) {
    throw FormatException(
      "El icono '$value' no pertenece al catálogo Material soportado en $path",
    );
  }
  return normalized;
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  return value == null ? null : DateTime.parse(value);
}

OmniLocalizedText? _optionalLocalized(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = json[key];
  return value == null ? null : OmniLocalizedText.fromJson(value, '$path.$key');
}

List<OmniLibraryBadge> _badges(Map<String, Object?> json, String path) {
  final value = json['badges'];
  if (value == null) return const <OmniLibraryBadge>[];
  if (value is! List) throw FormatException('badges inválido en $path');
  if (value.length > _maxBadges) {
    throw FormatException('Demasiados badges en $path');
  }
  return List<OmniLibraryBadge>.unmodifiable([
    for (var index = 0; index < value.length; index += 1)
      OmniLibraryBadge.fromJson(value[index], '$path.badges[$index]'),
  ]);
}

Set<String> _groups(Map<String, Object?> json, String path) {
  final value = json['groups'];
  if (value == null) return const <String>{};
  if (value is! List ||
      !value.every((entry) => entry is String && entry.isNotEmpty)) {
    throw FormatException('groups inválido en $path');
  }
  final groups = Set<String>.unmodifiable(value.cast<String>());
  if (groups.length != value.length) {
    throw FormatException('groups duplicados en $path');
  }
  return groups;
}

Map<String, Object?> _metadata(Map<String, Object?> json, String path) {
  final value = json['metadata'];
  if (value == null) return const <String, Object?>{};
  if (value is Map<String, Object?>) {
    if (value.length > _maxMetadataKeys) {
      throw FormatException('metadata demasiado grande en $path');
    }
    return Map<String, Object?>.unmodifiable(value);
  }
  throw FormatException('metadata inválido en $path');
}

String _endpointCacheKey(Uri endpoint) {
  final digest = sha256.convert(
    utf8.encode(endpoint.normalizePath().toString()),
  );
  return digest.toString();
}
