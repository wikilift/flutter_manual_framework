/// Shared presentation fallback order. Identity and authorization never use it.
List<String> localizedLanguageOrder(
  String? requested,
  String? defaultLanguage,
  Iterable<String> available,
) {
  final result = <String>[];
  void add(String? language) {
    final normalized = language?.replaceAll('_', '-');
    if (normalized == null || normalized.isEmpty) return;
    if (!result.contains(normalized)) result.add(normalized);
    final base = normalized.split('-').first;
    if (!result.contains(base)) result.add(base);
  }

  add(requested);
  add(defaultLanguage);
  add('en');
  for (final language in available.toList()..sort()) {
    add(language);
  }
  return result;
}

String? resolveLocalizedText(
  Map<String, String> values,
  String? requested, {
  String? defaultLanguage,
}) {
  for (final language in localizedLanguageOrder(
    requested,
    defaultLanguage,
    values.keys,
  )) {
    final value = values[language];
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}
