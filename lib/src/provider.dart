import 'dart:typed_data';

import 'distribution/manifest.dart';
import 'models.dart';

/// Supplies the SDK with the catalog of manuals available in the host app.
///
/// Implement this for static bundled manuals, generated registries or future
/// local/remote catalog strategies. A source only describes available manuals;
/// it does not render content or load runtime files directly.
abstract class OmniManualsSource {
  /// Creates a catalog source.
  const OmniManualsSource();

  /// Loads the local manual catalog used by [OmniManuals.initialize].
  ///
  /// This method must not perform remote update checks, downloads,
  /// installations or cache reconciliation. Remote-capable sources expose those
  /// operations through explicit update APIs.
  Future<List<OmniManualInfo>> loadManuals();

  /// Loads the hierarchical Flutter library.
  ///
  /// Sources that do not define collections inherit a flat root library with
  /// every manual returned by [loadManuals].
  Future<List<OmniLibraryEntry>> loadLibraryEntries() async => [
    for (final manual in await loadManuals())
      OmniManualLibraryEntry(manual: manual),
  ];

  /// Loads a runtime-relative asset, when this source owns local files.
  ///
  /// Sources that only provide catalog metadata can keep the default `null`
  /// implementation. Cached and directory-backed sources use this hook to let
  /// the embedded runtime serve manuals not bundled in the application binary.
  Future<Uint8List?> loadAsset(String relativePath) async => null;

  /// Releases source-owned resources.
  ///
  /// Most bundled/static sources do not need cleanup. Remote or cached sources
  /// can override this when they own connections, streams or temporary state.
  Future<void> dispose() async {}
}

/// Deprecated compatibility name for [OmniManualsSource].
///
/// New code should prefer [OmniManualsSource], which describes the role at SDK
/// level without exposing implementation terminology.
@Deprecated('Use OmniManualsSource instead.')
typedef OmniManualsProvider = OmniManualsSource;

/// Source capable of publishing a remote distribution manifest and ZIP
/// packages.
///
/// This contract is backend-neutral. HTTP, Firebase Storage, Azure Blob or
/// SharePoint implementations differ only in how they fetch bytes and obtain
/// authentication headers.
abstract class OmniManualsDistributionSource extends OmniManualsSource {
  /// Creates a distribution source.
  const OmniManualsDistributionSource();

  /// Downloads and parses the current remote manifest.
  Future<OmniDistributionManifest> fetchManifest();

  /// Opens a byte stream for a package advertised by [fetchManifest].
  Future<Stream<List<int>>> openPackage(OmniDistributionPackage package);
}
