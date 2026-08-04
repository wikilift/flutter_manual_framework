import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../distribution/progress.dart';
import '../distribution/service.dart';
import '../distribution/cache.dart';
import '../distribution/update_summary.dart';
import '../events.dart';
import '../errors.dart';
import '../library_catalog.dart';
import '../models.dart';
import '../provider.dart';
import '../state.dart';
import 'offline_runtime_server.dart';
import 'runtime_paths.dart';

final OmniManualsController omniManualsController = OmniManualsController();

final class OmniManualsController {
  OmniManualsConfig _config = const OmniManualsConfig();
  OmniManualsState _state = OmniManualsState.uninitialized;
  Future<void>? _initialization;
  List<OmniManualInfo> _manuals = const [];
  List<OmniLibraryEntry> _libraryEntries = const [];
  OfflineRuntimeServer? _server;
  OmniManualsSource? _effectiveSource;
  final ValueNotifier<OmniSyncProgress?> progress = ValueNotifier(null);
  final StreamController<OmniManualsEvent> _events =
      StreamController<OmniManualsEvent>.broadcast();

  OmniManualsState get state => _state;

  List<OmniManualInfo> get manuals => List.unmodifiable(_manuals);

  List<OmniLibraryEntry> get libraryEntries =>
      List.unmodifiable(_libraryEntries);

  Stream<OmniManualsEvent> get events => _events.stream;

  Future<void> initialize({OmniManualsConfig? config}) {
    final nextConfig = config ?? const OmniManualsConfig();
    if (_state == OmniManualsState.ready) {
      if (!identical(nextConfig.source, _config.source) ||
          !identical(nextConfig.catalogSource, _config.catalogSource) ||
          !setEquals(nextConfig.userGroups, _config.userGroups) ||
          nextConfig.defaultLanguage != _config.defaultLanguage ||
          nextConfig.publicApiBaseUrl != _config.publicApiBaseUrl ||
          !identical(nextConfig.onSyncProgress, _config.onSyncProgress)) {
        throw const OmniManualsException(
          code: OmniManualsErrorCode.configInvalid,
          message: 'OmniManuals ya está inicializado con otra configuración.',
          recoveryHint: 'Llama a OmniManuals.dispose() antes de reinicializar.',
        );
      }
      return Future<void>.value();
    }
    if (_state == OmniManualsState.initializing) return _initialization!;
    _config = nextConfig;
    _state = OmniManualsState.initializing;
    _initialization = _initialize(nextConfig);
    return _initialization!;
  }

  Future<void> _initialize(OmniManualsConfig config) async {
    try {
      _effectiveSource = _resolveSource(config.source);
      _manuals =
          await (_effectiveSource?.loadManuals() ??
              Future<List<OmniManualInfo>>.value(const []));
      _libraryEntries = await resolveLibraryEntries(
        catalogSource: config.catalogSource,
        language: config.defaultLanguage,
        userGroups: config.userGroups,
      );
      _server = OfflineRuntimeServer(source: _effectiveSource);
      _state = OmniManualsState.ready;
      _emitEvent(OmniManualsEvent(type: OmniManualsEventType.initialized));
    } catch (error) {
      _state = OmniManualsState.failed;
      throw OmniManualsException(
        code: OmniManualsErrorCode.initializationFailed,
        message: 'No se pudo inicializar Omni Manuals.',
        cause: error,
        recoveryHint: 'Revisa la configuración y el provider del SDK.',
        fatal: true,
      );
    }
  }

  OmniManualInfo manual(String id) {
    for (final descriptor in _manuals) {
      if (descriptor.id == id) return descriptor;
    }
    throw OmniManualsException(
      code: OmniManualsErrorCode.manualNotFound,
      message: 'No existe el manual "$id" en el catálogo del SDK.',
      context: id,
      recoveryHint: 'Regenera el registry o revisa el ID solicitado.',
    );
  }

  Future<List<OmniLibraryEntry>> resolveLibraryEntries({
    OmniLibraryCatalogSource? catalogSource,
    String? language,
    Set<String> userGroups = const <String>{'default'},
  }) async {
    if (_state != OmniManualsState.ready &&
        _state != OmniManualsState.initializing) {
      await initialize(config: _config);
    }

    final catalog = await _tryLoadLibraryCatalog(catalogSource);
    if (catalog != null) {
      return catalog.toLibraryEntries(
        registry: _manuals,
        language: language ?? _config.defaultLanguage,
        userGroups: userGroups.isEmpty ? const <String>{'default'} : userGroups,
      );
    }

    final legacyEntries = await _tryLoadLegacySourceLibraryEntries();
    if (legacyEntries.isNotEmpty) return legacyEntries;

    return _flatLibraryEntries();
  }

  Future<void> dispose() async {
    if (_state == OmniManualsState.uninitialized ||
        _state == OmniManualsState.disposed) {
      return;
    }
    _state = OmniManualsState.disposing;
    await _server?.stop();
    await _effectiveSource?.dispose();
    progress.value = null;
    if (!_events.isClosed) {
      _emitEvent(OmniManualsEvent(type: OmniManualsEventType.libraryChanged));
    }
    _server = null;
    _effectiveSource = null;
    _manuals = const [];
    _libraryEntries = const [];
    _initialization = null;
    _config = const OmniManualsConfig();
    _state = OmniManualsState.disposed;
  }

  Future<OmniLibraryCatalog?> _tryLoadLibraryCatalog(
    OmniLibraryCatalogSource? catalogSource,
  ) async {
    final source = catalogSource ?? _config.catalogSource;
    if (source == null) return null;
    try {
      return await source.loadCatalog();
    } catch (error) {
      debugPrint('[OmniManuals] Library Catalog rejected: $error');
      return null;
    }
  }

  Future<List<OmniLibraryEntry>> _tryLoadLegacySourceLibraryEntries() async {
    final source = _effectiveSource;
    if (source == null) return const <OmniLibraryEntry>[];
    try {
      final entries = await source.loadLibraryEntries();
      return entries.isEmpty ? const <OmniLibraryEntry>[] : entries;
    } catch (_) {
      return const <OmniLibraryEntry>[];
    }
  }

  List<OmniLibraryEntry> _flatLibraryEntries() => [
    for (final manual in _manuals) OmniManualLibraryEntry(manual: manual),
  ];

  Future<Uri> manualUri({
    required String id,
    String? language,
    bool embedded = false,
  }) async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    if (!isSafeManualId(id)) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.configInvalid,
        message: 'ID de manual no seguro: $id',
        context: id,
      );
    }
    manual(id);
    final server = _server ??= OfflineRuntimeServer(source: _effectiveSource);
    final baseUri = await server.start();
    final selectedLanguage = language ?? _config.defaultLanguage;
    debugPrint(
      '[OmniManuals] opening manual id=$id language=${selectedLanguage ?? "auto"}',
    );
    final queryParameters = <String, String>{'manualId': id};
    if (selectedLanguage != null) {
      queryParameters['language'] = selectedLanguage;
    }
    final publicApiBaseUrl = _config.publicApiBaseUrl;
    if (publicApiBaseUrl != null) {
      queryParameters['publicApiBaseUrl'] = publicApiBaseUrl.toString();
    }
    if (embedded) queryParameters['shell'] = 'embedded';
    return baseUri.replace(queryParameters: queryParameters);
  }

  OmniManualsSource? _resolveSource(OmniManualsSource? source) {
    if (source is OmniManualsDistributionSource) {
      return CachedSource(upstream: source, onProgress: _handleProgress);
    }
    if (source is CachedSource) {
      return _withControllerProgress(source);
    }
    if (source is OmniCompositeSource) {
      final cached = source.cached;
      if (cached is CachedSource) {
        return OmniCompositeSource(
          bundled: source.bundled,
          cached: _withControllerProgress(cached),
        );
      }
    }
    return source;
  }

  Future<void> installManual(String id) async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.manualNotFound,
        message: 'El manual "$id" no pertenece a un catálogo instalable.',
        context: id,
      );
    }
    await source.installManual(id);
    _manuals = await source.loadManuals();
    _libraryEntries = await resolveLibraryEntries(
      catalogSource: _config.catalogSource,
      language: _config.defaultLanguage,
      userGroups: _config.userGroups,
    );
    _emitEvent(
      OmniManualsEvent(
        type: OmniManualsEventType.manualInstalled,
        manualId: id,
      ),
    );
    _emitLibraryChanged();
  }

  Future<void> updateManual(String id) async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.manualNotFound,
        message: 'El manual "$id" no pertenece a un catálogo actualizable.',
        context: id,
      );
    }
    await source.updateManual(id);
    _manuals = await source.loadManuals();
    _libraryEntries = await resolveLibraryEntries(
      catalogSource: _config.catalogSource,
      language: _config.defaultLanguage,
      userGroups: _config.userGroups,
    );
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.manualUpdated, manualId: id),
    );
    _emitLibraryChanged();
  }

  Future<void> removeManual(String id) async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.manualNotFound,
        message: 'El manual "$id" no pertenece a un catálogo desinstalable.',
        context: id,
      );
    }
    await source.removeManual(id);
    _manuals = await source.loadManuals();
    _libraryEntries = await resolveLibraryEntries(
      catalogSource: _config.catalogSource,
      language: _config.defaultLanguage,
      userGroups: _config.userGroups,
    );
    _emitLibraryChanged();
  }

  Future<OmniUpdateSummary> checkForUpdates() async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) {
      return OmniUpdateSummary(
        newManuals: const <OmniManualUpdateEntry>[],
        updates: const <OmniManualUpdateEntry>[],
        unchanged: const <OmniManualUpdateEntry>[],
        noLongerAvailable: const <OmniManualUpdateEntry>[],
        totalDownloadBytes: 0,
        checkedAt: DateTime.now().toUtc(),
        usedCachedMetadata: false,
      );
    }
    _emitEvent(OmniManualsEvent(type: OmniManualsEventType.updateCheckStarted));
    final summary = await source.checkForUpdates(
      userGroups: _config.userGroups,
    );
    final catalogChanged = await _catalogHasRemoteUpdate();
    final enriched = OmniUpdateSummary(
      newManuals: summary.newManuals,
      updates: summary.updates,
      unchanged: summary.unchanged,
      noLongerAvailable: summary.noLongerAvailable,
      totalDownloadBytes: summary.totalDownloadBytes,
      checkedAt: summary.checkedAt,
      usedCachedMetadata: summary.usedCachedMetadata,
      catalogChanged: catalogChanged,
    );
    _emitEvent(
      OmniManualsEvent(
        type: OmniManualsEventType.updateCheckCompleted,
        updateSummary: enriched,
      ),
    );
    return enriched;
  }

  Future<void> synchronizeManuals(Set<String> ids) async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) {
      throw const OmniManualsException(
        code: OmniManualsErrorCode.manualNotFound,
        message:
            'La configuración actual no contiene una fuente sincronizable.',
      );
    }
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.synchronizationStarted),
    );
    try {
      await source.synchronizeManuals(ids);
      await _reloadManualsOnly();
      final catalogUpdated = await _refreshRemoteCatalogIfPossible();
      if (catalogUpdated) {
        _emitEvent(OmniManualsEvent(type: OmniManualsEventType.catalogUpdated));
      }
    } catch (error) {
      _emitEvent(
        OmniManualsEvent(
          type: OmniManualsEventType.synchronizationFailed,
          error: error,
        ),
      );
      rethrow;
    }
    await _reloadLocalCatalog();
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.synchronizationCompleted),
    );
    _emitLibraryChanged();
  }

  Future<void> synchronizeAllAvailable() async {
    if (_state != OmniManualsState.ready) await initialize(config: _config);
    final source = _findCachedSource(_effectiveSource);
    if (source == null) return;
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.synchronizationStarted),
    );
    try {
      await source.synchronizeAllAvailable(userGroups: _config.userGroups);
      await _reloadManualsOnly();
      final catalogUpdated = await _refreshRemoteCatalogIfPossible();
      if (catalogUpdated) {
        _emitEvent(OmniManualsEvent(type: OmniManualsEventType.catalogUpdated));
      }
    } catch (error) {
      _emitEvent(
        OmniManualsEvent(
          type: OmniManualsEventType.synchronizationFailed,
          error: error,
        ),
      );
      rethrow;
    }
    await _reloadLocalCatalog();
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.synchronizationCompleted),
    );
    _emitLibraryChanged();
  }

  Future<void> cancelSynchronization() async {
    final source = _findCachedSource(_effectiveSource);
    _emitEvent(
      OmniManualsEvent(type: OmniManualsEventType.synchronizationCancelling),
    );
    await source?.cancelSynchronization();
  }

  void _handleProgress(OmniSyncProgress nextProgress) {
    progress.value = nextProgress;
    _config.onSyncProgress?.call(nextProgress);
    _emitEvent(
      OmniManualsEvent(
        type: OmniManualsEventType.synchronizationProgress,
        progress: nextProgress,
      ),
    );
    if (nextProgress.stage == OmniSyncStage.cancelled) {
      _emitEvent(
        OmniManualsEvent(type: OmniManualsEventType.synchronizationCancelled),
      );
    }
  }

  CachedSource _withControllerProgress(CachedSource source) {
    return CachedSource(
      upstream: source.upstream,
      cache: source.cache,
      onProgress: (nextProgress) {
        source.onProgress?.call(nextProgress);
        _handleProgress(nextProgress);
      },
    );
  }

  CachedSource? _findCachedSource(OmniManualsSource? source) {
    if (source is CachedSource) return source;
    if (source is OmniCompositeSource) {
      return _findCachedSource(source.cached);
    }
    return null;
  }

  Future<void> _reloadLocalCatalog() async {
    await _reloadManualsOnly();
    _libraryEntries = await resolveLibraryEntries(
      catalogSource: _config.catalogSource,
      language: _config.defaultLanguage,
      userGroups: _config.userGroups,
    );
  }

  Future<void> _reloadManualsOnly() async {
    _manuals =
        await (_effectiveSource?.loadManuals() ??
            Future<List<OmniManualInfo>>.value(const []));
  }

  Future<bool> _catalogHasRemoteUpdate() async {
    final source = _cachedCatalogSource(_config.catalogSource);
    return source == null ? false : source.hasRemoteUpdate();
  }

  Future<bool> _refreshRemoteCatalogIfPossible() async {
    final source = _cachedCatalogSource(_config.catalogSource);
    if (source == null) {
      await _config.catalogSource?.refresh();
      return false;
    }
    return source.refreshIfValid(
      availableManualIds: _manuals.map((manual) => manual.id).toSet(),
    );
  }

  OmniCachedCatalogSource? _cachedCatalogSource(
    OmniLibraryCatalogSource? source,
  ) {
    if (source is OmniCachedCatalogSource) return source;
    if (source is OmniFallbackCatalogSource) {
      for (final item in source.sources) {
        final match = _cachedCatalogSource(item);
        if (match != null) return match;
      }
    }
    return null;
  }

  void _emitLibraryChanged() {
    _emitEvent(OmniManualsEvent(type: OmniManualsEventType.libraryChanged));
  }

  void _emitEvent(OmniManualsEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
