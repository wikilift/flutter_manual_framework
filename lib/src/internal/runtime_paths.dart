import 'dart:typed_data';

const String packageRuntimeAssetRoot = 'packages/omni_manuals/assets/runtime';

final RegExp _manualIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');
final RegExp _languagePattern = RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$');

bool isSafeManualId(String value) => _manualIdPattern.hasMatch(value);

bool isSafeLanguageCode(String value) => _languagePattern.hasMatch(value);

String? safeRelativePath(String rawPath) {
  final decoded = Uri.decodeComponent(rawPath);
  final path = decoded == '/'
      ? 'index.html'
      : decoded.replaceFirst(RegExp(r'^/+'), '');
  if (path.isEmpty || path.contains(r'\') || path.contains('//')) return null;
  if (path
      .split('/')
      .any((part) => part.isEmpty || part == '.' || part == '..')) {
    return null;
  }
  return path;
}

String mimeType(String relativePath) {
  final extension = relativePath.split('.').last.toLowerCase();
  return switch (extension) {
    'html' => 'text/html; charset=utf-8',
    'js' => 'text/javascript; charset=utf-8',
    'css' => 'text/css; charset=utf-8',
    'json' => 'application/json; charset=utf-8',
    'svg' => 'image/svg+xml',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}

final class ByteRange {
  const ByteRange(this.start, this.endInclusive);

  final int start;
  final int endInclusive;

  int get length => endInclusive - start + 1;

  Uint8List slice(Uint8List bytes) =>
      Uint8List.sublistView(bytes, start, endInclusive + 1);
}

ByteRange? parseRangeHeader(String? header, int length) {
  if (header == null || !header.startsWith('bytes=') || length <= 0) {
    return null;
  }
  final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header);
  if (match == null) return null;
  final startText = match.group(1) ?? '';
  final endText = match.group(2) ?? '';
  if (startText.isEmpty && endText.isEmpty) return null;
  final start = startText.isEmpty
      ? length - int.parse(endText)
      : int.parse(startText);
  final end = startText.isEmpty || endText.isEmpty
      ? length - 1
      : int.parse(endText);
  if (start < 0 || end < start || start >= length) return null;
  return ByteRange(start, end >= length ? length - 1 : end);
}
