import 'dart:convert';

import '../models.dart';

/// Current remote manifest version supported by this SDK.
const int omniDistributionManifestVersion = 1;

/// Remote JSON manifest describing the manual and auxiliary packages available
/// from a distribution backend.
final class OmniDistributionManifest {
  const OmniDistributionManifest({
    required this.manifestVersion,
    required this.minimumSdkVersion,
    required this.runtimeVersion,
    required this.generatedAt,
    required this.manuals,
    this.packages = const <OmniDistributionPackage>[],
    this.signature,
  });

  final int manifestVersion;
  final String minimumSdkVersion;
  final String runtimeVersion;
  final DateTime generatedAt;
  final List<OmniDistributionManual> manuals;
  final List<OmniDistributionPackage> packages;
  final OmniDistributionSignature? signature;

  factory OmniDistributionManifest.fromJson(Map<String, Object?> json) {
    final manifestVersion = _requiredInt(json, 'manifestVersion');
    final minimumSdkVersion = _requiredString(json, 'minimumSdkVersion');
    final runtimeVersion = _requiredString(json, 'runtimeVersion');
    final generatedAt = DateTime.parse(_requiredString(json, 'generatedAt'));
    final manuals = _requiredList(json, 'manuals')
        .map(
          (entry) =>
              OmniDistributionManual.fromJson(_asObject(entry, 'manuals[]')),
        )
        .toList(growable: false);
    final packages = _optionalList(json, 'packages')
        .map(
          (entry) =>
              OmniDistributionPackage.fromJson(_asObject(entry, 'packages[]')),
        )
        .toList(growable: false);
    final signature = json['signature'];
    return OmniDistributionManifest(
      manifestVersion: manifestVersion,
      minimumSdkVersion: minimumSdkVersion,
      runtimeVersion: runtimeVersion,
      generatedAt: generatedAt,
      manuals: manuals,
      packages: packages,
      signature: signature == null
          ? null
          : OmniDistributionSignature.fromJson(
              _asObject(signature, 'signature'),
            ),
    );
  }

  factory OmniDistributionManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'El manifest remoto debe ser un objeto JSON.',
      );
    }
    return OmniDistributionManifest.fromJson(decoded);
  }
}

/// Placeholder signature descriptor for future signed manifests.
///
/// Signatures are parsed and preserved as metadata, but not enforced yet.
final class OmniDistributionSignature {
  const OmniDistributionSignature({
    required this.algorithm,
    required this.keyId,
    required this.value,
  });

  final String algorithm;
  final String keyId;
  final String value;

  factory OmniDistributionSignature.fromJson(Map<String, Object?> json) {
    return OmniDistributionSignature(
      algorithm: _requiredString(json, 'algorithm'),
      keyId: _requiredString(json, 'keyId'),
      value: _requiredString(json, 'value'),
    );
  }
}

/// Manual entry advertised by a distribution manifest.
final class OmniDistributionManual {
  const OmniDistributionManual({
    required this.id,
    required this.displayName,
    required this.version,
    required this.hashSha256,
    required this.compressedSize,
    required this.downloadUrl,
    required this.languages,
    required this.date,
    this.dependencies = const <String>[],
    this.groups = const <String>{},
    this.icon,
    this.poster,
  });

  final String id;
  final String displayName;
  final String version;
  final String hashSha256;
  final int compressedSize;
  final Uri downloadUrl;
  final List<String> languages;
  final List<String> dependencies;
  final Set<String> groups;
  final DateTime date;
  final String? icon;
  final String? poster;

  OmniManualInfo toManualInfo() => OmniManualInfo(
    id: id,
    title: displayName,
    version: version,
    languages: languages,
    icon: icon,
    poster: poster,
  );

  OmniDistributionPackage toPackage() => OmniDistributionPackage(
    id: id,
    kind: OmniDistributionPackageKind.manual,
    version: version,
    hashSha256: hashSha256,
    compressedSize: compressedSize,
    downloadUrl: downloadUrl,
    dependencies: dependencies,
    date: date,
  );

  factory OmniDistributionManual.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    return OmniDistributionManual(
      id: id,
      displayName: _optionalString(json, 'displayName') ?? id,
      version: _requiredString(json, 'version'),
      hashSha256: _requiredString(json, 'hashSha256'),
      compressedSize: _requiredInt(json, 'compressedSize'),
      downloadUrl: Uri.parse(_requiredString(json, 'downloadUrl')),
      languages: _requiredStringList(json, 'languages'),
      dependencies: _optionalStringList(json, 'dependencies'),
      groups: _optionalStringSet(json, 'groups'),
      date: DateTime.parse(_requiredString(json, 'date')),
      icon: _optionalString(json, 'icon'),
      poster: _optionalString(json, 'poster'),
    );
  }
}

/// ZIP package advertised by a distribution manifest.
final class OmniDistributionPackage {
  const OmniDistributionPackage({
    required this.id,
    required this.kind,
    required this.version,
    required this.hashSha256,
    required this.compressedSize,
    required this.downloadUrl,
    required this.date,
    this.dependencies = const <String>[],
  });

  final String id;
  final OmniDistributionPackageKind kind;
  final String version;
  final String hashSha256;
  final int compressedSize;
  final Uri downloadUrl;
  final DateTime date;
  final List<String> dependencies;

  factory OmniDistributionPackage.fromJson(Map<String, Object?> json) {
    return OmniDistributionPackage(
      id: _requiredString(json, 'id'),
      kind: OmniDistributionPackageKind.parse(_requiredString(json, 'kind')),
      version: _requiredString(json, 'version'),
      hashSha256: _requiredString(json, 'hashSha256'),
      compressedSize: _requiredInt(json, 'compressedSize'),
      downloadUrl: Uri.parse(_requiredString(json, 'downloadUrl')),
      dependencies: _optionalStringList(json, 'dependencies'),
      date: DateTime.parse(_requiredString(json, 'date')),
    );
  }
}

enum OmniDistributionPackageKind {
  manual,
  assets,
  videos;

  static OmniDistributionPackageKind parse(String value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('Tipo de paquete no soportado: $value');
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Campo obligatorio inválido: $key');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw FormatException('Campo obligatorio inválido: $key');
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('Campo obligatorio inválido: $key');
}

List<Object?> _optionalList(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is List ? value : const <Object?>[];
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final values = _requiredList(json, key);
  if (values.every((value) => value is String && value.isNotEmpty)) {
    return List<String>.unmodifiable(values.cast<String>());
  }
  throw FormatException('Campo obligatorio inválido: $key');
}

List<String> _optionalStringList(Map<String, Object?> json, String key) {
  final values = _optionalList(json, key);
  if (values.every((value) => value is String && value.isNotEmpty)) {
    return List<String>.unmodifiable(values.cast<String>());
  }
  throw FormatException('Campo opcional inválido: $key');
}

Set<String> _optionalStringSet(Map<String, Object?> json, String key) {
  final values = _optionalList(json, key);
  final output = <String>{};
  for (final value in values) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Campo opcional inválido: $key');
    }
    output.add(value);
  }
  return Set<String>.unmodifiable(output);
}

Map<String, Object?> _asObject(Object? value, String path) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Entrada inválida en $path');
}
