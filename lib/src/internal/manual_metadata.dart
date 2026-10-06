import 'dart:convert';
import 'dart:io';

import '../models.dart';
import 'localization.dart';

final class OmniManualMetadata {
  const OmniManualMetadata({
    required this.id,
    required this.title,
    this.subtitle,
    this.version,
    this.minimumRuntimeVersion,
    this.languages = const <String>[],
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? version;
  final String? minimumRuntimeVersion;
  final List<String> languages;

  OmniManualInfo toManualInfo({String? icon, String? poster}) => OmniManualInfo(
    id: id,
    title: title,
    subtitle: subtitle,
    version: version,
    minimumRuntimeVersion: minimumRuntimeVersion,
    languages: languages,
    icon: icon,
    poster: poster,
  );
}

Future<OmniManualMetadata?> readManualMetadataFromDirectory(
  Directory root, {
  required String fallbackId,
  String? fallbackVersion,
  List<String> fallbackLanguages = const <String>[],
  String? language,
}) async {
  final manualFile = File('${root.path}/manual.json');
  if (!await manualFile.exists()) return null;
  return readManualMetadata(
    loadText: (relative) async {
      if (!_safeRelativePath(relative)) return null;
      final file = File('${root.path}/$relative');
      return await file.exists() ? file.readAsString() : null;
    },
    fallbackId: fallbackId,
    fallbackVersion: fallbackVersion,
    fallbackLanguages: fallbackLanguages,
    language: language,
  );
}

Future<OmniManualMetadata?> readManualMetadata({
  required Future<String?> Function(String relative) loadText,
  required String fallbackId,
  String? fallbackVersion,
  List<String> fallbackLanguages = const [],
  String? language,
}) async {
  final textCache = <String, Future<String?>>{};
  final originalLoader = loadText;
  loadText = (relative) =>
      textCache.putIfAbsent(relative, () => originalLoader(relative));
  final raw = await loadText('manual.json');
  if (raw == null) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) return null;
  final id = _string(decoded['id']) ?? fallbackId;
  final languages = _strings(decoded['languages']);
  final defaultLanguage = _string(decoded['defaultLanguage']);
  final content = decoded['content'];
  final languageOrder = _languageOrder(
    requested: language,
    defaultLanguage: defaultLanguage,
    languages: languages.isEmpty ? fallbackLanguages : languages,
    content: content,
  );
  final title =
      await _resolveKeyedText(
        loadText: loadText,
        manualJson: decoded,
        keyName: 'titleKey',
        languageOrder: languageOrder,
      ) ??
      _localizedText(decoded['title'], languageOrder) ??
      _localizedText(decoded['name'], languageOrder) ??
      _localizedText((decoded['metadata'] as Map?)?['title'], languageOrder) ??
      id;
  final subtitle =
      await _resolveKeyedText(
        loadText: loadText,
        manualJson: decoded,
        keyName: 'subtitleKey',
        languageOrder: languageOrder,
      ) ??
      _localizedText(decoded['subtitle'], languageOrder) ??
      _localizedText((decoded['metadata'] as Map?)?['subtitle'], languageOrder);
  return OmniManualMetadata(
    id: id,
    title: title,
    subtitle: subtitle,
    version: _string(decoded['version']) ?? fallbackVersion,
    minimumRuntimeVersion: _string(decoded['minimumRuntimeVersion']),
    languages: languages.isEmpty ? fallbackLanguages : languages,
  );
}

Future<String?> _resolveKeyedText({
  required Future<String?> Function(String relative) loadText,
  required Map<String, Object?> manualJson,
  required String keyName,
  required List<String> languageOrder,
}) async {
  final metadata = manualJson['metadata'];
  final key = metadata is Map<String, Object?>
      ? _string(metadata[keyName])
      : null;
  final fallbackKey = _string(manualJson[keyName]);
  final lookupKey = key ?? fallbackKey;
  if (lookupKey == null) return null;
  for (final language in languageOrder) {
    final content = await _loadContent(loadText, manualJson, language);
    if (content == null) continue;
    final direct = content[lookupKey];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    final nested = _nestedLookup(content, lookupKey);
    if (nested is String && nested.trim().isNotEmpty) return nested.trim();
  }
  return null;
}

Future<Map<String, Object?>?> _loadContent(
  Future<String?> Function(String relative) loadText,
  Map<String, Object?> manualJson,
  String language,
) async {
  final content = manualJson['content'];
  if (content is! Map<String, Object?>) return null;
  final relative = _string(content[language]);
  if (relative == null || !_safeRelativePath(relative)) return null;
  final raw = await loadText(relative);
  if (raw == null) return null;
  final decoded = jsonDecode(raw);
  return decoded is Map<String, Object?> ? decoded : null;
}

Object? _nestedLookup(Map<String, Object?> content, String key) {
  Object? current = content;
  for (final part in key.split('.')) {
    if (current is! Map<String, Object?>) return null;
    current = current[part];
  }
  return current;
}

String? _localizedText(Object? value, List<String> languageOrder) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is Map) {
    for (final language in languageOrder) {
      final item = value[language];
      if (item is String && item.trim().isNotEmpty) return item.trim();
    }
    for (final key in value.keys.whereType<String>().toList()..sort()) {
      final item = value[key];
      if (item is String && item.trim().isNotEmpty) return item.trim();
    }
  }
  return null;
}

List<String> _languageOrder({
  required String? requested,
  required String? defaultLanguage,
  required List<String> languages,
  required Object? content,
}) {
  return localizedLanguageOrder(requested, defaultLanguage, {
    ...languages,
    if (content is Map) ...content.keys.whereType<String>(),
  });
}

bool _safeRelativePath(String value) {
  if (value.isEmpty || value.contains(r'\') || value.startsWith('/')) {
    return false;
  }
  final parts = value.split('/');
  return !parts.any((part) => part.isEmpty || part == '.' || part == '..');
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _strings(Object? value) => value is List
    ? List<String>.unmodifiable(
        value.whereType<String>().where((item) => item.isNotEmpty),
      )
    : const <String>[];
