import 'package:flutter/foundation.dart';

import 'config.dart';
import 'distribution/progress.dart';
import 'distribution/update_summary.dart';
import 'events.dart';
import 'internal/sdk_controller.dart';
import 'models.dart';
import 'state.dart';

abstract final class OmniManuals {
  /// Current lifecycle state of the SDK singleton.
  ///
  /// Most applications do not need this; it is useful for tests and custom
  /// integrations that need to react to initialization or disposal.
  static OmniManualsState get state => omniManualsController.state;

  /// Manual catalog loaded from the configured [OmniManualsSource].
  ///
  /// The returned list contains Flutter-facing metadata only. Manual content is
  /// still loaded and rendered by the bundled web runtime.
  static List<OmniManualInfo> get manuals => omniManualsController.manuals;

  /// Hierarchical library entries loaded from the configured source.
  static List<OmniLibraryEntry> get libraryEntries =>
      omniManualsController.libraryEntries;

  /// Latest installation or update progress reported by the SDK.
  static ValueListenable<OmniSyncProgress?> get syncProgress =>
      omniManualsController.progress;

  static Stream<OmniManualsEvent> get events => omniManualsController.events;

  /// Initializes the SDK once for the current Flutter process.
  ///
  /// Call this before showing [OmniManualsPage]. If omitted by simple widgets,
  /// the SDK attempts to initialize with default configuration, which is useful
  /// only for demos that bundle the default assets.
  static Future<void> initialize({OmniManualsConfig? config}) =>
      omniManualsController.initialize(config: config);

  /// Returns metadata for a manual already present in the loaded catalog.
  ///
  /// This does not parse or render manual JSON. It is a catalog lookup used by
  /// advanced integrations that need to validate IDs before opening a widget.
  static OmniManualInfo manual(String id) => omniManualsController.manual(id);

  /// Checks remote metadata explicitly without downloading or installing ZIPs.
  static Future<OmniUpdateSummary> checkForUpdates() =>
      omniManualsController.checkForUpdates();

  /// Installs an optional manual from the dynamic catalog.
  static Future<void> installManual(String id) =>
      omniManualsController.installManual(id);

  /// Updates an installed manual when a newer remote package is available.
  static Future<void> updateManual(String id) =>
      omniManualsController.updateManual(id);

  /// Synchronizes the selected manuals explicitly.
  static Future<void> synchronizeManuals(Set<String> ids) =>
      omniManualsController.synchronizeManuals(ids);

  /// Synchronizes every visible new/update package explicitly.
  static Future<void> synchronizeAllAvailable() =>
      omniManualsController.synchronizeAllAvailable();

  /// Removes the local copy of an optional manual.
  static Future<void> removeManual(String id) =>
      omniManualsController.removeManual(id);

  /// Cancels the active metadata check or synchronization, when possible.
  static Future<void> cancelSynchronization() =>
      omniManualsController.cancelSynchronization();

  /// Stops private SDK resources and releases the configured source.
  ///
  /// Applications normally call this from tests or when intentionally
  /// reconfiguring the SDK in the same process.
  static Future<void> dispose() => omniManualsController.dispose();
}
