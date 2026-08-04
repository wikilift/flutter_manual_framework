import '../errors.dart';

/// Synchronization lifecycle event emitted by [OmniDistributionService].
final class OmniSyncProgress {
  const OmniSyncProgress({
    required this.stage,
    this.manualId,
    this.packageId,
    this.completedBytes,
    this.totalBytes,
    this.globalProgress,
    this.message,
    this.error,
  });

  final OmniSyncStage stage;
  final String? manualId;
  final String? packageId;
  final int? completedBytes;
  final int? totalBytes;
  final double? globalProgress;
  final String? message;
  final OmniManualsException? error;
  @override
  String toString() {
    return 'OmniSyncProgress('
        'packageId: $packageId, '
        'message: $message, '
        'completedBytes: $completedBytes, '
        'totalBytes: $totalBytes, '
        'globalProgress: $globalProgress'
        ')';
  }
}

enum OmniSyncStage {
  checkingCatalog,
  checkingManifest,
  loadingManifest,
  comparingPackages,
  downloadingPackage,
  validatingPackage,
  extractingPackage,
  installingPackage,
  updatingRegistry,
  removingPackage,
  complete,
  cancelled,
  failed,
}

typedef OmniSyncProgressSink = void Function(OmniSyncProgress progress);
