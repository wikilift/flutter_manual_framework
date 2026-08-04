import 'distribution/progress.dart';
import 'distribution/update_summary.dart';

enum OmniManualsEventType {
  initialized,
  updateCheckStarted,
  updateCheckCompleted,
  synchronizationStarted,
  synchronizationProgress,
  synchronizationCancelling,
  synchronizationCancelled,
  synchronizationCompleted,
  synchronizationFailed,
  manualInstalled,
  manualUpdated,
  catalogUpdated,
  libraryChanged,
}

final class OmniManualsEvent {
  OmniManualsEvent({
    required this.type,
    DateTime? timestamp,
    this.manualId,
    this.progress,
    this.updateSummary,
    this.error,
    this.message,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  final OmniManualsEventType type;

  /// Momento exacto en que se emitió el evento.
  final DateTime timestamp;

  /// Manual afectado, cuando el evento corresponde a uno concreto.
  final String? manualId;

  /// Progreso actual de una sincronización.
  final OmniSyncProgress? progress;

  /// Resultado de una comprobación de actualizaciones.
  final OmniUpdateSummary? updateSummary;

  /// Error original cuando la operación falla.
  final Object? error;

  /// Descripción opcional pensada para logs y diagnóstico.
  final String? message;

  @override
  String toString() {
    final fields = <String>[
      'type: $type',
      'timestamp: ${timestamp.toIso8601String()}',
      if (manualId != null) 'manualId: $manualId',
      if (progress != null) 'progress: $progress',
      if (updateSummary != null) 'updateSummary: $updateSummary',
      if (message != null) 'message: $message',
      if (error != null) 'error: $error',
    ];

    return 'OmniManualsEvent(${fields.join(', ')})';
  }
}
