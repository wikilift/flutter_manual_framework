import '../errors.dart';

/// Calculated state of a manual in relation to a remote distribution catalog.
enum OmniManualUpdateState {
  available,
  updateAvailable,
  installed,
  unavailable,
  downloading,
  failed,
}

/// Remote/local comparison entry returned by `checkForUpdates`.
final class OmniManualUpdateEntry {
  const OmniManualUpdateEntry({
    required this.manualId,
    required this.packageId,
    required this.title,
    required this.installedVersion,
    required this.remoteVersion,
    required this.remoteHashSha256,
    required this.downloadBytes,
    required this.languages,
    required this.groups,
    required this.state,
    this.icon,
    this.poster,
    this.error,
  });

  final String manualId;
  final String packageId;
  final String title;
  final String? installedVersion;
  final String remoteVersion;
  final String remoteHashSha256;
  final int downloadBytes;
  final List<String> languages;
  final String? icon;
  final String? poster;
  final Set<String> groups;
  final OmniManualUpdateState state;
  final OmniManualsException? error;
}

/// Result of an explicit remote metadata check.
///
/// This model never implies that a package was downloaded or installed. Host
/// applications use it to decide their own UX and download policy.
final class OmniUpdateSummary {
  const OmniUpdateSummary({
    required this.newManuals,
    required this.updates,
    required this.unchanged,
    required this.noLongerAvailable,
    required this.totalDownloadBytes,
    required this.checkedAt,
    required this.usedCachedMetadata,
    this.catalogChanged = false,
  });

  final List<OmniManualUpdateEntry> newManuals;
  final List<OmniManualUpdateEntry> updates;
  final List<OmniManualUpdateEntry> unchanged;
  final List<OmniManualUpdateEntry> noLongerAvailable;
  final int totalDownloadBytes;
  final DateTime checkedAt;
  final bool usedCachedMetadata;
  final bool catalogChanged;

  bool get hasChanges =>
      newManuals.isNotEmpty ||
      updates.isNotEmpty ||
      noLongerAvailable.isNotEmpty ||
      catalogChanged;

  List<OmniManualUpdateEntry> get downloadable => <OmniManualUpdateEntry>[
    ...newManuals,
    ...updates,
  ];
  @override
  String toString() {
    return 'OmniUpdateSummary('
        'newManuals: ${newManuals.length}, '
        'updates: ${updates.length}, '
        'noLongerAvailable: ${noLongerAvailable.length}, '
        'catalogChanged: $catalogChanged, '
        'totalDownloadBytes: $totalDownloadBytes, '
        'usedCachedMetadata: $usedCachedMetadata'
        ')';
  }
}

/// Result of an explicit local-cache reconciliation.
final class OmniReconcileResult {
  const OmniReconcileResult({required this.unavailable, required this.removed});

  final List<OmniManualUpdateEntry> unavailable;
  final List<String> removed;
}
