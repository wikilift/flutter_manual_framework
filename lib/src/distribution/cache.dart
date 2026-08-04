import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../provider.dart';
import '../internal/manual_metadata.dart';
import 'manifest.dart';

const String _registryFileName = 'registry.json';
const String _contentDirectoryName = 'content';

/// Persistent local storage for distributed manual packages.
final class OmniManualsCache {
  OmniManualsCache({required this.root});

  final Directory root;

  Directory get contentRoot => Directory('${root.path}/$_contentDirectoryName');

  File get registryFile => File('${root.path}/$_registryFileName');

  static Future<OmniManualsCache> defaultCache() async {
    final support = await getApplicationSupportDirectory();
    return OmniManualsCache(root: Directory('${support.path}/omni_manuals'));
  }

  Future<void> ensureReady() async {
    await root.create(recursive: true);
    await contentRoot.create(recursive: true);
  }

  Future<OmniDistributionManifest?> loadRegistry() async {
    if (!await registryFile.exists()) return null;
    return OmniDistributionManifest.parse(await registryFile.readAsString());
  }

  Future<List<OmniManualInfo>> loadManuals() async {
    final registry = await loadRegistry();
    if (registry == null) return const <OmniManualInfo>[];
    final manuals = <OmniManualInfo>[];
    for (final manual in registry.manuals) {
      final metadata = await readManualMetadataFromDirectory(
        Directory(
          '${contentRoot.path}/${packageContentRoot(manual.toPackage())}',
        ),
        fallbackId: manual.id,
        fallbackVersion: manual.version,
        fallbackLanguages: manual.languages,
      );
      manuals.add(
        (metadata?.toManualInfo(icon: manual.icon, poster: manual.poster)) ??
            manual.toManualInfo(),
      );
    }
    return List<OmniManualInfo>.unmodifiable(manuals);
  }

  Future<Uint8List?> loadAsset(String relativePath) async {
    final file = _safeFile(contentRoot, relativePath);
    if (file == null || !await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<Map<String, CachedPackageRecord>> loadPackageRecords() async {
    final registry = await loadRegistry();
    if (registry == null) return const <String, CachedPackageRecord>{};
    return <String, CachedPackageRecord>{
      for (final package in _allPackages(registry))
        package.id: CachedPackageRecord(
          id: package.id,
          version: package.version,
          hashSha256: package.hashSha256,
          contentRoot: packageContentRoot(package),
        ),
    };
  }

  Future<void> replaceWith({
    required Directory stagedContentRoot,
    required String manifestJson,
  }) async {
    await ensureReady();
    final backup = Directory('${root.path}/content.previous');
    final registryTemp = File('${root.path}/$_registryFileName.next');
    if (await backup.exists()) await backup.delete(recursive: true);
    if (await registryTemp.exists()) await registryTemp.delete();
    await registryTemp.writeAsString(manifestJson, flush: true);
    if (await contentRoot.exists()) {
      await contentRoot.rename(backup.path);
    }
    try {
      await stagedContentRoot.rename(contentRoot.path);
      if (await registryFile.exists()) await registryFile.delete();
      await registryTemp.rename(registryFile.path);
      if (await backup.exists()) await backup.delete(recursive: true);
    } catch (_) {
      if (await registryTemp.exists()) await registryTemp.delete();
      if (await contentRoot.exists()) await contentRoot.delete(recursive: true);
      if (await backup.exists()) await backup.rename(contentRoot.path);
      rethrow;
    }
  }

  Future<void> removeManualPackage(String manualId, String packageId) async {
    await ensureReady();
    final registry = await loadRegistry();
    if (registry == null) return;
    final currentPackages = allPackages(registry);
    final nextManuals = registry.manuals
        .where((manual) => manual.id != manualId)
        .toList(growable: false);
    final nextPackages = registry.packages
        .where((package) => package.id != packageId)
        .toList(growable: false);
    final staging = createStagingRoot();
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    if (await contentRoot.exists()) {
      await _copyDirectory(contentRoot, staging);
    }
    OmniDistributionPackage? removedPackage;
    for (final package in currentPackages) {
      if (package.id == packageId) {
        removedPackage = package;
        break;
      }
    }
    final rootToRemove = removedPackage == null
        ? 'manuals/$manualId'
        : packageContentRoot(removedPackage);
    if (rootToRemove != null) {
      final directory = Directory('${staging.path}/$rootToRemove');
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    await replaceWith(
      stagedContentRoot: staging,
      manifestJson: manifestToJson(
        OmniDistributionManifest(
          manifestVersion: registry.manifestVersion,
          minimumSdkVersion: registry.minimumSdkVersion,
          runtimeVersion: registry.runtimeVersion,
          generatedAt: DateTime.now().toUtc(),
          manuals: nextManuals,
          packages: nextPackages,
          signature: registry.signature,
        ),
      ),
    );
  }

  Directory createStagingRoot() => Directory(
    '${root.path}/staging-${DateTime.now().microsecondsSinceEpoch}',
  );
}

/// Source backed by an unpacked local directory.
final class DirectorySource extends OmniManualsSource {
  const DirectorySource({required this.root});

  final Directory root;

  @override
  Future<List<OmniManualInfo>> loadManuals() async {
    final registry = File('${root.path}/$_registryFileName');
    if (await registry.exists()) {
      final manifest = OmniDistributionManifest.parse(
        await registry.readAsString(),
      );
      return manifest.manuals
          .map((manual) => manual.toManualInfo())
          .toList(growable: false);
    }
    final manualsRoot = Directory('${root.path}/manuals');
    if (!await manualsRoot.exists()) return const <OmniManualInfo>[];
    final manuals = <OmniManualInfo>[];
    await for (final entity in manualsRoot.list()) {
      if (entity is! Directory) continue;
      final id = _basename(entity.path);
      if (id.startsWith('_')) continue;
      manuals.add(OmniManualInfo(id: id, title: id));
    }
    manuals.sort((left, right) => left.id.compareTo(right.id));
    return manuals;
  }

  @override
  Future<Uint8List?> loadAsset(String relativePath) async {
    final file = _safeFile(root, relativePath);
    if (file == null || !await file.exists()) return null;
    return file.readAsBytes();
  }
}

/// Static in-memory catalog source for local integrations and tests.
final class LocalSource extends OmniManualsSource {
  const LocalSource({required this.manuals});

  final List<OmniManualInfo> manuals;

  @override
  Future<List<OmniManualInfo>> loadManuals() async =>
      List<OmniManualInfo>.unmodifiable(manuals);
}

/// Local source that combines bundled and cached manuals without network.
///
/// Cached manuals win over bundled manuals when their semantic version is newer
/// or equal. If the cached copy disappears, the bundled copy automatically
/// becomes visible again on the next local load.
final class OmniCompositeSource extends OmniManualsSource {
  const OmniCompositeSource({required this.bundled, required this.cached});

  final OmniManualsSource bundled;
  final OmniManualsSource cached;

  @override
  Future<List<OmniManualInfo>> loadManuals() async {
    final bundledManuals = await bundled.loadManuals();
    final cachedManuals = await cached.loadManuals();
    final byId = <String, _CompositeManual>{};
    for (final manual in bundledManuals) {
      byId[manual.id] = _CompositeManual(manual, bundled);
    }
    for (final manual in cachedManuals) {
      final current = byId[manual.id];
      if (current == null || _preferCached(manual, current.info)) {
        byId[manual.id] = _CompositeManual(manual, cached);
      }
    }
    final result = byId.values.map((entry) => entry.info).toList();
    result.sort((left, right) => left.id.compareTo(right.id));
    return List<OmniManualInfo>.unmodifiable(result);
  }

  @override
  Future<List<OmniLibraryEntry>> loadLibraryEntries() async => [
    for (final manual in await loadManuals())
      OmniManualLibraryEntry(manual: manual),
  ];

  @override
  Future<Uint8List?> loadAsset(String relativePath) async {
    final manualId = _manualIdFromAsset(relativePath);
    if (manualId != null) {
      final winners = {
        for (final entry in await _winnerEntries()) entry.info.id: entry.source,
      };
      final winner = winners[manualId];
      if (winner != null) {
        final bytes = await winner.loadAsset(relativePath);
        if (bytes != null) return bytes;
      }
    }
    return await cached.loadAsset(relativePath) ??
        await bundled.loadAsset(relativePath);
  }

  @override
  Future<void> dispose() async {
    await cached.dispose();
    await bundled.dispose();
  }

  Future<List<_CompositeManual>> _winnerEntries() async {
    final bundledManuals = await bundled.loadManuals();
    final cachedManuals = await cached.loadManuals();
    final byId = <String, _CompositeManual>{};
    for (final manual in bundledManuals) {
      byId[manual.id] = _CompositeManual(manual, bundled);
    }
    for (final manual in cachedManuals) {
      final current = byId[manual.id];
      if (current == null || _preferCached(manual, current.info)) {
        byId[manual.id] = _CompositeManual(manual, cached);
      }
    }
    return byId.values.toList(growable: false);
  }
}

final class _CompositeManual {
  const _CompositeManual(this.info, this.source);

  final OmniManualInfo info;
  final OmniManualsSource source;
}

String? _manualIdFromAsset(String relativePath) {
  final parts = relativePath.split('/');
  return parts.length >= 2 && parts.first == 'manuals' ? parts[1] : null;
}

bool _preferCached(OmniManualInfo cached, OmniManualInfo bundled) {
  final cachedVersion = cached.version;
  final bundledVersion = bundled.version;
  if (cachedVersion == null || bundledVersion == null) return true;
  return _compareSemVer(cachedVersion, bundledVersion) >= 0;
}

int _compareSemVer(String left, String right) {
  final a = _semverParts(left);
  final b = _semverParts(right);
  if (a == null || b == null) return left == right ? 0 : 1;
  for (var index = 0; index < 3; index += 1) {
    final comparison = a[index].compareTo(b[index]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

List<int>? _semverParts(String value) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value);
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

final class CachedPackageRecord {
  const CachedPackageRecord({
    required this.id,
    required this.version,
    required this.hashSha256,
    this.contentRoot,
  });

  final String id;
  final String version;
  final String hashSha256;
  final String? contentRoot;
}

List<OmniDistributionPackage> allPackages(OmniDistributionManifest manifest) =>
    _allPackages(manifest);

String? packageContentRoot(OmniDistributionPackage package) {
  return switch (package.kind) {
    OmniDistributionPackageKind.manual => 'manuals/${package.id}',
    OmniDistributionPackageKind.assets => 'assets/${package.id}',
    OmniDistributionPackageKind.videos => 'videos/${package.id}',
  };
}

List<OmniDistributionPackage> _allPackages(OmniDistributionManifest manifest) {
  final packages = <String, OmniDistributionPackage>{
    for (final package in manifest.packages) package.id: package,
  };
  for (final manual in manifest.manuals) {
    packages.putIfAbsent(manual.id, manual.toPackage);
  }
  return packages.values.toList(growable: false);
}

File? _safeFile(Directory root, String relativePath) {
  if (relativePath.isEmpty || relativePath.contains(r'\')) return null;
  final parts = relativePath.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    return null;
  }
  return File('${root.path}/${parts.join('/')}');
}

String manifestToJson(OmniDistributionManifest manifest) => jsonEncode({
  'manifestVersion': manifest.manifestVersion,
  'minimumSdkVersion': manifest.minimumSdkVersion,
  'runtimeVersion': manifest.runtimeVersion,
  'generatedAt': manifest.generatedAt.toIso8601String(),
  'manuals': [
    for (final manual in manifest.manuals)
      {
        'id': manual.id,
        'version': manual.version,
        'hashSha256': manual.hashSha256,
        'compressedSize': manual.compressedSize,
        'downloadUrl': manual.downloadUrl.toString(),
        'languages': manual.languages,
        'dependencies': manual.dependencies,
        if (manual.groups.isNotEmpty) 'groups': manual.groups.toList(),
        'date': manual.date.toIso8601String(),
        if (manual.icon != null) 'icon': manual.icon,
        if (manual.poster != null) 'poster': manual.poster,
      },
  ],
  'packages': [
    for (final package in manifest.packages)
      {
        'id': package.id,
        'kind': package.kind.name,
        'version': package.version,
        'hashSha256': package.hashSha256,
        'compressedSize': package.compressedSize,
        'downloadUrl': package.downloadUrl.toString(),
        'dependencies': package.dependencies,
        'date': package.date.toIso8601String(),
      },
  ],
  if (manifest.signature != null)
    'signature': {
      'algorithm': manifest.signature!.algorithm,
      'keyId': manifest.signature!.keyId,
      'value': manifest.signature!.value,
    },
});

String _basename(String path) =>
    Uri.file(path).pathSegments.where((segment) => segment.isNotEmpty).last;

Future<void> _copyDirectory(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entity in from.list(recursive: false)) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final target = '${to.path}/$name';
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      await File(target).parent.create(recursive: true);
      await entity.copy(target);
    }
  }
}
