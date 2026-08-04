import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../errors.dart';
import '../models.dart';
import '../provider.dart';
import 'cache.dart';
import 'manifest.dart';
import 'progress.dart';
import 'update_summary.dart';

/// Backend-neutral OTA synchronizer for Omni Manuals ZIP packages.
final class OmniDistributionService {
  OmniDistributionService({
    required this.source,
    required this.cache,
    this.onProgress,
    OmniCancellationToken? cancellationToken,
  }) : _cancellationToken = cancellationToken ?? OmniCancellationToken();

  final OmniManualsDistributionSource source;
  final OmniManualsCache cache;
  final OmniSyncProgressSink? onProgress;
  final OmniCancellationToken _cancellationToken;

  void cancel() => _cancellationToken.cancel();

  Future<OmniUpdateSummary> checkForUpdates({
    Set<String> userGroups = const <String>{'default'},
  }) async {
    await cache.ensureReady();
    final checkedAt = DateTime.now().toUtc();
    var usedCachedMetadata = false;
    _emit(const OmniSyncProgress(stage: OmniSyncStage.checkingManifest));
    OmniDistributionManifest manifest;
    try {
      manifest = await source.fetchManifest();
      _validateManifest(manifest);
    } catch (_) {
      final cached = await cache.loadRegistry();
      if (cached == null) rethrow;
      manifest = cached;
      usedCachedMetadata = true;
    }
    _cancellationToken.throwIfCancelled();

    _emit(const OmniSyncProgress(stage: OmniSyncStage.comparingPackages));
    final installed = await cache.loadPackageRecords();
    final remotePackages = {
      for (final package in allPackages(manifest)) package.id: package,
    };
    final effectiveGroups = normalizeUserGroups(userGroups);
    final visibleManuals = [
      for (final manual in manifest.manuals)
        if (_visibleForGroups(manual.groups, effectiveGroups)) manual,
    ];
    final entries = <OmniManualUpdateEntry>[];
    final visibleManualIds = <String>{};
    for (final manual in visibleManuals) {
      if (!visibleManualIds.add(manual.id)) continue;
      final package = remotePackages[manual.id];
      if (package == null) continue;
      final local = installed[manual.id];
      final state = local == null
          ? OmniManualUpdateState.available
          : local.version != package.version ||
                local.hashSha256 != package.hashSha256
          ? OmniManualUpdateState.updateAvailable
          : OmniManualUpdateState.installed;
      entries.add(
        OmniManualUpdateEntry(
          manualId: manual.id,
          packageId: manual.id,
          title: manual.displayName,
          installedVersion: local?.version,
          remoteVersion: package.version,
          remoteHashSha256: package.hashSha256,
          downloadBytes: package.compressedSize,
          languages: manual.languages,
          icon: manual.icon,
          poster: manual.poster,
          groups: manual.groups,
          state: state,
        ),
      );
    }
    final installedManuals =
        (await cache.loadRegistry())?.manuals ??
        const <OmniDistributionManual>[];
    final noLongerAvailable = [
      for (final manual in installedManuals)
        if (!visibleManualIds.contains(manual.id))
          OmniManualUpdateEntry(
            manualId: manual.id,
            packageId: manual.id,
            title: manual.displayName,
            installedVersion: manual.version,
            remoteVersion: manual.version,
            remoteHashSha256: manual.hashSha256,
            downloadBytes: 0,
            languages: manual.languages,
            icon: manual.icon,
            poster: manual.poster,
            groups: manual.groups,
            state: OmniManualUpdateState.unavailable,
          ),
    ];
    final newManuals = [
      for (final entry in entries)
        if (entry.state == OmniManualUpdateState.available) entry,
    ];
    final updates = [
      for (final entry in entries)
        if (entry.state == OmniManualUpdateState.updateAvailable) entry,
    ];
    final unchanged = [
      for (final entry in entries)
        if (entry.state == OmniManualUpdateState.installed) entry,
    ];
    _emit(const OmniSyncProgress(stage: OmniSyncStage.complete));
    return OmniUpdateSummary(
      newManuals: List.unmodifiable(newManuals),
      updates: List.unmodifiable(updates),
      unchanged: List.unmodifiable(unchanged),
      noLongerAvailable: List.unmodifiable(noLongerAvailable),
      totalDownloadBytes:
          newManuals.fold<int>(0, (sum, entry) => sum + entry.downloadBytes) +
          updates.fold<int>(0, (sum, entry) => sum + entry.downloadBytes),
      checkedAt: checkedAt,
      usedCachedMetadata: usedCachedMetadata,
    );
  }

  Future<OmniDistributionManifest> synchronize() async {
    await cache.ensureReady();
    _cancellationToken.throwIfCancelled();
    _emit(const OmniSyncProgress(stage: OmniSyncStage.checkingManifest));
    final manifest = await source.fetchManifest();
    _validateManifest(manifest);
    _emit(const OmniSyncProgress(stage: OmniSyncStage.comparingPackages));
    final current = await cache.loadPackageRecords();
    final requiredPackages = allPackages(manifest);
    final changed = requiredPackages
        .where(
          (package) =>
              current[package.id]?.hashSha256 != package.hashSha256 ||
              current[package.id]?.version != package.version,
        )
        .toList(growable: false);
    final removed = current.keys
        .where((id) => requiredPackages.every((package) => package.id != id))
        .toList(growable: false);

    if (changed.isEmpty &&
        removed.isEmpty &&
        await cache.registryFile.exists()) {
      _emit(const OmniSyncProgress(stage: OmniSyncStage.complete));
      return manifest;
    }

    final staging = cache.createStagingRoot();
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    if (await cache.contentRoot.exists()) {
      await _copyDirectory(cache.contentRoot, staging);
    }

    try {
      for (final package in changed) {
        _cancellationToken.throwIfCancelled();
        await _downloadValidateExtract(package, staging);
      }
      for (final packageId in removed) {
        _emit(
          OmniSyncProgress(
            stage: OmniSyncStage.removingPackage,
            packageId: packageId,
          ),
        );
        await _removePackageContent(packageId, current, staging);
      }
      _emit(const OmniSyncProgress(stage: OmniSyncStage.updatingRegistry));
      await cache.replaceWith(
        stagedContentRoot: staging,
        manifestJson: manifestToJson(manifest),
      );
      _emit(const OmniSyncProgress(stage: OmniSyncStage.complete));
      return manifest;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<OmniDistributionManifest> synchronizePackages(
    OmniDistributionManifest remoteManifest,
    Set<String> packageIds,
  ) async {
    await cache.ensureReady();
    _cancellationToken.throwIfCancelled();
    _validateManifest(remoteManifest);
    _emit(const OmniSyncProgress(stage: OmniSyncStage.comparingPackages));
    final currentRegistry = await cache.loadRegistry();
    final current = await cache.loadPackageRecords();
    final selected = _selectPackageClosure(remoteManifest, packageIds);
    final changed = selected
        .where(
          (package) =>
              current[package.id]?.hashSha256 != package.hashSha256 ||
              current[package.id]?.version != package.version,
        )
        .toList(growable: false);

    if (changed.isEmpty && currentRegistry != null) return currentRegistry;

    final staging = cache.createStagingRoot();
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    if (await cache.contentRoot.exists()) {
      await _copyDirectory(cache.contentRoot, staging);
    }

    try {
      for (final package in changed) {
        _cancellationToken.throwIfCancelled();
        await _downloadValidateExtract(package, staging);
      }
      _emit(const OmniSyncProgress(stage: OmniSyncStage.updatingRegistry));
      final nextRegistry = _mergeRegistry(
        currentRegistry: currentRegistry,
        remoteManifest: remoteManifest,
        installedPackageIds: {
          ...current.keys,
          for (final package in selected) package.id,
        },
      );
      await cache.replaceWith(
        stagedContentRoot: staging,
        manifestJson: manifestToJson(nextRegistry),
      );
      _emit(const OmniSyncProgress(stage: OmniSyncStage.complete));
      return nextRegistry;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _downloadValidateExtract(
    OmniDistributionPackage package,
    Directory staging,
  ) async {
    _cancellationToken.throwIfCancelled();
    _emit(
      OmniSyncProgress(
        stage: OmniSyncStage.downloadingPackage,
        packageId: package.id,
        totalBytes: package.compressedSize,
      ),
    );
    final download = File('${cache.root.path}/${package.id}.download');
    if (await download.exists()) await download.delete();
    final sink = download.openWrite();
    var completed = 0;
    try {
      final stream = await source.openPackage(package);
      await for (final chunk in stream) {
        _cancellationToken.throwIfCancelled();
        completed += chunk.length;
        sink.add(chunk);
        _emit(
          OmniSyncProgress(
            stage: OmniSyncStage.downloadingPackage,
            packageId: package.id,
            completedBytes: completed,
            totalBytes: package.compressedSize,
          ),
        );
      }
      await sink.flush();
      await sink.close();
    } catch (error) {
      await sink.close();
      if (await download.exists()) await download.delete();
      if (error is OmniManualsException &&
          error.code == OmniManualsErrorCode.synchronizationCancelled) {
        _emit(
          OmniSyncProgress(
            stage: OmniSyncStage.cancelled,
            packageId: package.id,
            error: error,
          ),
        );
      }
      rethrow;
    }

    _emit(
      OmniSyncProgress(
        stage: OmniSyncStage.validatingPackage,
        packageId: package.id,
      ),
    );
    final actualHash = await _sha256File(download, _cancellationToken);
    if (actualHash.toLowerCase() != package.hashSha256.toLowerCase()) {
      await download.delete();
      throw OmniManualsException(
        code: OmniManualsErrorCode.packageInvalid,
        message: 'SHA256 inválido para ${package.id}.',
        context: package.id,
        recoveryHint: '$actualHash != ${package.hashSha256}',
      );
    }

    _emit(
      OmniSyncProgress(
        stage: OmniSyncStage.extractingPackage,
        packageId: package.id,
      ),
    );
    _cancellationToken.throwIfCancelled();
    await _extractZip(download, staging, package);
    await download.delete();
  }

  Future<void> _extractZip(
    File file,
    Directory destination,
    OmniDistributionPackage package,
  ) async {
    final input = InputFileStream(file.path);
    try {
      // archive 3.x does not expose ZIP decodeStream; decodeBuffer keeps file
      // backed input and avoids loading the whole ZIP into a Dart List first.
      final archive = ZipDecoder().decodeBuffer(input);
      if (archive.length > _maxZipEntries) {
        throw OmniManualsException(
          code: OmniManualsErrorCode.packageInvalid,
          message: 'ZIP con demasiadas entradas: ${archive.length}.',
        );
      }
      final extractRoot = _extractRootForPackage(
        destination,
        package,
        archive.files.map((entry) => entry.name),
      );
      var totalUncompressed = 0;
      for (final entry in archive) {
        _cancellationToken.throwIfCancelled();
        final target = _safeExtractPath(extractRoot, entry.name);
        if (target == null) {
          throw OmniManualsException(
            code: OmniManualsErrorCode.packageInvalid,
            message: 'Ruta insegura en ZIP: ${entry.name}',
          );
        }
        if (entry.isSymbolicLink) {
          throw OmniManualsException(
            code: OmniManualsErrorCode.packageInvalid,
            message: 'Enlace simbólico no permitido en ZIP: ${entry.name}',
          );
        }
        final entrySize = _archiveEntrySize(entry);
        totalUncompressed += entrySize;
        if (totalUncompressed > _maxUncompressedBytes) {
          throw const OmniManualsException(
            code: OmniManualsErrorCode.packageInvalid,
            message: 'ZIP excede el tamaño descomprimido máximo.',
          );
        }
        if (entry.isFile) {
          final output = File(target);
          await output.parent.create(recursive: true);
          final outputStream = OutputFileStream(output.path);
          try {
            entry.writeContent(outputStream);
          } catch (_) {
            await outputStream.close();
            if (await output.exists()) await output.delete();
            rethrow;
          } finally {
            await outputStream.close();
          }
          if (entrySize == 0 && !await output.exists()) {
            await output.create();
          }
        } else {
          await Directory(target).create(recursive: true);
        }
      }
    } finally {
      await input.close();
    }
  }

  void _validateManifest(OmniDistributionManifest manifest) {
    if (manifest.manifestVersion != omniDistributionManifestVersion) {
      throw StateError(
        'Versión de manifest no soportada: ${manifest.manifestVersion}',
      );
    }
    final packageIds = <String>{};
    final manualIds = <String>{};
    final packages = allPackages(manifest);
    for (final package in packages) {
      if (!_safeIdentifier.hasMatch(package.id)) {
        throw StateError('ID de paquete inseguro en manifest: ${package.id}');
      }
      if (!packageIds.add(package.id)) {
        throw StateError('Paquete duplicado en manifest: ${package.id}');
      }
      if (!_sha256Pattern.hasMatch(package.hashSha256)) {
        throw StateError('SHA256 inválido en paquete: ${package.id}');
      }
      if (package.compressedSize <= 0) {
        throw StateError(
          'Tamaño comprimido inválido en paquete: ${package.id}',
        );
      }
    }
    for (final manual in manifest.manuals) {
      if (!_safeIdentifier.hasMatch(manual.id)) {
        throw StateError('ID de manual inseguro en manifest: ${manual.id}');
      }
      if (!manualIds.add(manual.id)) {
        throw StateError('Manual duplicado en manifest: ${manual.id}');
      }
      for (final dependency in manual.dependencies) {
        if (!packageIds.contains(dependency)) {
          throw StateError(
            'Dependencia inexistente "$dependency" en manual ${manual.id}',
          );
        }
      }
    }
    for (final package in packages) {
      for (final dependency in package.dependencies) {
        if (!packageIds.contains(dependency)) {
          throw StateError(
            'Dependencia inexistente "$dependency" en paquete ${package.id}',
          );
        }
        if (dependency == package.id) {
          throw StateError('Dependencia circular directa en ${package.id}');
        }
      }
    }
  }

  void _emit(OmniSyncProgress progress) => onProgress?.call(progress);

  List<OmniDistributionPackage> _selectPackageClosure(
    OmniDistributionManifest manifest,
    Set<String> packageIds,
  ) {
    final packages = {
      for (final package in allPackages(manifest)) package.id: package,
    };
    final selected = <String>{};
    void visit(String id) {
      if (!selected.add(id)) return;
      final package = packages[id];
      if (package == null) {
        throw StateError('Paquete inexistente en manifest: $id');
      }
      for (final dependency in package.dependencies) {
        visit(dependency);
      }
    }

    for (final id in packageIds) {
      visit(id);
    }
    return [
      for (final package in allPackages(manifest))
        if (selected.contains(package.id)) package,
    ];
  }

  OmniDistributionManifest _mergeRegistry({
    required OmniDistributionManifest? currentRegistry,
    required OmniDistributionManifest remoteManifest,
    required Set<String> installedPackageIds,
  }) {
    final currentPackages = currentRegistry == null
        ? const <OmniDistributionPackage>[]
        : allPackages(currentRegistry);
    final remotePackages = {
      for (final package in allPackages(remoteManifest)) package.id: package,
    };
    final nextPackages = <String, OmniDistributionPackage>{
      for (final package in currentPackages) package.id: package,
    };
    for (final id in installedPackageIds) {
      final package = remotePackages[id];
      if (package != null) nextPackages[id] = package;
    }
    final nextManuals = [
      for (final manual in remoteManifest.manuals)
        if (nextPackages.containsKey(manual.id)) manual,
    ];
    nextPackages.removeWhere(
      (id, package) =>
          package.kind == OmniDistributionPackageKind.manual &&
          nextManuals.every((manual) => manual.id != id),
    );
    return OmniDistributionManifest(
      manifestVersion: remoteManifest.manifestVersion,
      minimumSdkVersion: remoteManifest.minimumSdkVersion,
      runtimeVersion: remoteManifest.runtimeVersion,
      generatedAt: DateTime.now().toUtc(),
      manuals: nextManuals,
      packages: nextPackages.values
          .where(
            (package) => package.kind != OmniDistributionPackageKind.manual,
          )
          .toList(growable: false),
      signature: remoteManifest.signature,
    );
  }

  Future<void> _removePackageContent(
    String packageId,
    Map<String, CachedPackageRecord> current,
    Directory staging,
  ) async {
    final record = current[packageId];
    final relativeRoot = record?.contentRoot ?? _legacyContentRoot(packageId);
    if (relativeRoot == null) return;
    final directory = Directory('${staging.path}/$relativeRoot');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  String? _legacyContentRoot(String packageId) {
    return 'manuals/$packageId';
  }
}

int _archiveEntrySize(ArchiveFile entry) {
  final size = entry.size;
  if (size < 0) {
    throw OmniManualsException(
      code: OmniManualsErrorCode.packageInvalid,
      message: 'Entrada ZIP con tamaño negativo: ${entry.name}',
    );
  }
  return size;
}

Directory _extractRootForPackage(
  Directory destination,
  OmniDistributionPackage package,
  Iterable<String> entryNames,
) {
  if (package.kind != OmniDistributionPackageKind.manual) return destination;
  final expectedPrefix = 'manuals/${package.id}/';
  final nonDirectoryNames = entryNames.where((name) => !name.endsWith('/'));
  final alreadyNested = nonDirectoryNames.any(
    (name) => name.startsWith(expectedPrefix),
  );
  return alreadyNested
      ? destination
      : Directory('${destination.path}/manuals/${package.id}');
}

/// Cache decorator for remote distribution sources.
final class CachedSource extends OmniManualsSource {
  CachedSource({
    required this.upstream,
    this.cache,
    this.onProgress,
    @Deprecated(
      'loadManuals is always local; use checkForUpdates/synchronize explicitly.',
    )
    this.syncOnLoad = false,
  });

  final OmniManualsDistributionSource upstream;
  final OmniManualsCache? cache;
  final OmniSyncProgressSink? onProgress;
  @Deprecated(
    'loadManuals is always local; use checkForUpdates/synchronize explicitly.',
  )
  final bool syncOnLoad;
  OmniManualsCache? _resolvedCache;
  Future<List<OmniManualInfo>>? _loadInFlight;
  OmniDistributionManifest? _remoteManifest;
  final Set<String> _activeManualIds = <String>{};
  final Map<String, Object> _failures = <String, Object>{};
  OmniCancellationToken? _cancellationToken;

  Future<OmniManualsCache> resolveCache() async =>
      _resolvedCache ??= cache ?? await OmniManualsCache.defaultCache();

  @override
  Future<List<OmniManualInfo>> loadManuals() async {
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    final load = _loadManuals();
    _loadInFlight = load;
    try {
      return await load;
    } finally {
      if (identical(_loadInFlight, load)) _loadInFlight = null;
    }
  }

  Future<List<OmniManualInfo>> _loadManuals() async {
    final resolvedCache = await resolveCache();
    return resolvedCache.loadManuals();
  }

  Future<void> installManual(String manualId) async {
    await _installOrUpdateManual(manualId);
  }

  Future<void> updateManual(String manualId) async {
    await _installOrUpdateManual(manualId);
  }

  Future<OmniUpdateSummary> checkForUpdates({
    Set<String> userGroups = const <String>{'default'},
  }) async {
    final resolvedCache = await resolveCache();
    _cancellationToken = OmniCancellationToken();
    try {
      return await OmniDistributionService(
        source: upstream,
        cache: resolvedCache,
        onProgress: onProgress,
        cancellationToken: _cancellationToken,
      ).checkForUpdates(userGroups: userGroups);
    } finally {
      _cancellationToken = null;
    }
  }

  Future<void> synchronizeManuals(Set<String> manualIds) async {
    if (manualIds.isEmpty) return;
    final resolvedCache = await resolveCache();
    _remoteManifest = null;
    final manifest = await _loadRemoteManifest();
    final availableManualIds = manifest.manuals
        .map((manual) => manual.id)
        .toSet();
    for (final manualId in manualIds) {
      if (!availableManualIds.contains(manualId)) {
        throw StateError('Manual desconocido: $manualId');
      }
    }
    _cancellationToken = OmniCancellationToken();
    try {
      await OmniDistributionService(
        source: upstream,
        cache: resolvedCache,
        onProgress: onProgress,
        cancellationToken: _cancellationToken,
      ).synchronizePackages(manifest, manualIds);
    } finally {
      _cancellationToken = null;
    }
  }

  Future<void> synchronizeAllAvailable({
    Set<String> userGroups = const <String>{'default'},
  }) async {
    final summary = await checkForUpdates(userGroups: userGroups);
    await synchronizeManuals({
      for (final entry in summary.downloadable) entry.manualId,
    });
  }

  Future<OmniReconcileResult> reconcileInstalledContent({
    Set<String> userGroups = const <String>{'default'},
    bool removeUnavailable = false,
  }) async {
    final summary = await checkForUpdates(userGroups: userGroups);
    final removed = <String>[];
    if (removeUnavailable) {
      final resolvedCache = await resolveCache();
      for (final entry in summary.noLongerAvailable) {
        await resolvedCache.removeManualPackage(
          entry.manualId,
          entry.packageId,
        );
        removed.add(entry.manualId);
      }
    }
    return OmniReconcileResult(
      unavailable: summary.noLongerAvailable,
      removed: List.unmodifiable(removed),
    );
  }

  Future<void> cancelSynchronization() async {
    _cancellationToken?.cancel();
  }

  Future<void> removeManual(String manualId) async {
    final resolvedCache = await resolveCache();
    await resolvedCache.removeManualPackage(manualId, manualId);
    _failures.remove(manualId);
  }

  @override
  Future<Uint8List?> loadAsset(String relativePath) async {
    final resolvedCache = await resolveCache();
    return resolvedCache.loadAsset(relativePath);
  }

  @override
  Future<void> dispose() => upstream.dispose();

  Future<void> _installOrUpdateManual(String manualId) async {
    final resolvedCache = await resolveCache();
    _remoteManifest = null;
    _activeManualIds.add(manualId);
    _failures.remove(manualId);
    _cancellationToken = OmniCancellationToken();
    try {
      final manifest = await _loadRemoteManifest();
      if (!manifest.manuals.any((manual) => manual.id == manualId)) {
        throw StateError('Manual desconocido: $manualId');
      }
      await OmniDistributionService(
        source: upstream,
        cache: resolvedCache,
        onProgress: onProgress,
        cancellationToken: _cancellationToken,
      ).synchronizePackages(manifest, {manualId});
    } catch (error) {
      _failures[manualId] = error;
      rethrow;
    } finally {
      _activeManualIds.remove(manualId);
      _cancellationToken = null;
    }
  }

  Future<OmniDistributionManifest> _loadRemoteManifest() async {
    return _remoteManifest ??= await upstream.fetchManifest();
  }
}

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

String? _safeExtractPath(Directory root, String entryName) {
  final normalizedEntryName = entryName.endsWith('/')
      ? entryName.substring(0, entryName.length - 1)
      : entryName;
  if (normalizedEntryName.isEmpty ||
      normalizedEntryName.contains(r'\') ||
      normalizedEntryName.startsWith('/')) {
    return null;
  }
  final parts = normalizedEntryName.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    return null;
  }
  final rootUri = root.absolute.uri;
  final targetUri = rootUri.resolve(parts.join('/')).normalizePath();
  final rootPath = rootUri.toFilePath();
  final targetPath = targetUri.toFilePath();
  final normalizedRoot = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  if (!targetPath.startsWith(normalizedRoot)) return null;
  return targetPath;
}

bool _visibleForGroups(Set<String> groups, Set<String> effectiveGroups) =>
    groups.isEmpty || groups.any(effectiveGroups.contains);

Set<String> normalizeUserGroups(Set<String> userGroups) =>
    userGroups.isEmpty ? const <String>{'default'} : userGroups;

Future<String> _sha256File(File file, OmniCancellationToken token) async {
  final output = _DigestSink();
  final input = sha256.startChunkedConversion(output);
  try {
    await for (final chunk in file.openRead()) {
      token.throwIfCancelled();
      input.add(chunk);
    }
  } finally {
    input.close();
  }
  return output.digest.toString();
}

final class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest {
    final value = _digest;
    if (value == null) {
      throw StateError('SHA256 no finalizado.');
    }
    return value;
  }

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}

final class OmniCancellationToken {
  var _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  void throwIfCancelled() {
    if (!_cancelled) return;
    throw const OmniManualsException(
      code: OmniManualsErrorCode.synchronizationCancelled,
      message: 'Sincronización cancelada por la app host.',
    );
  }
}

const int _maxZipEntries = 4096;
const int _maxUncompressedBytes = 1024 * 1024 * 1024;
final RegExp _safeIdentifier = RegExp(r'^[a-z0-9][a-z0-9_-]*$');
final RegExp _sha256Pattern = RegExp(r'^[a-fA-F0-9]{64}$');
