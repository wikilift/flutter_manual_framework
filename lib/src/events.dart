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
  assessmentSubmitted,
}

final class OmniAssessmentResult {
  const OmniAssessmentResult({
    required this.manualId,
    required this.testId,
    required this.attempt,
    required this.maxAttempts,
    required this.score,
    required this.passingScore,
    required this.passed,
    required this.answers,
    required this.remainingAttempts,
    required this.navigationGate,
  });

  factory OmniAssessmentResult.fromJson(Map<String, Object?> json) {
    final manualId = _optionalString(json['manualId']);
    final testId = _requiredString(json, 'testId');
    final attempt = _requiredInt(json, 'attempt');
    final maxAttempts = _requiredInt(json, 'maxAttempts');
    final score = _requiredNum(json, 'score').toDouble();
    final passingScore = _requiredNum(json, 'passingScore').toDouble();
    final passed = _requiredBool(json, 'passed');
    final remainingAttempts = _optionalInt(json['remainingAttempts']);
    final navigationGate = _requiredBool(json, 'navigationGate');
    final answers = _answersMap(json['answers']);

    return OmniAssessmentResult(
      manualId: manualId,
      testId: testId,
      attempt: attempt,
      maxAttempts: maxAttempts,
      score: score,
      passingScore: passingScore,
      passed: passed,
      answers: answers,
      remainingAttempts: remainingAttempts,
      navigationGate: navigationGate,
    );
  }

  final String? manualId;
  final String testId;
  final int attempt;
  final int maxAttempts;
  final double score;
  final double passingScore;
  final bool passed;
  final Map<String, List<String>> answers;
  final int? remainingAttempts;
  final bool navigationGate;

  @override
  String toString() {
    return 'OmniAssessmentResult('
        'manualId: $manualId, '
        'testId: $testId, '
        'attempt: $attempt, '
        'maxAttempts: $maxAttempts, '
        'score: $score, '
        'passingScore: $passingScore, '
        'passed: $passed, '
        'remainingAttempts: $remainingAttempts, '
        'navigationGate: $navigationGate, '
        'answers: $answers'
        ')';
  }
}

final class OmniManualsEvent {
  OmniManualsEvent({
    required this.type,
    DateTime? timestamp,
    this.manualId,
    this.progress,
    this.updateSummary,
    this.assessmentResult,
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

  /// Resultado emitido por el runtime al finalizar un intento de assessment.
  final OmniAssessmentResult? assessmentResult;

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
      if (assessmentResult != null) 'assessmentResult: $assessmentResult',
      if (message != null) 'message: $message',
      if (error != null) 'error: $error',
    ];

    return 'OmniManualsEvent(${fields.join(', ')})';
  }
}

String? _optionalString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('assessmentSubmitted.$key debe ser string no vacío.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('assessmentSubmitted.$key debe ser int.');
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  throw const FormatException(
    'assessmentSubmitted.remainingAttempts debe ser int o null.',
  );
}

num _requiredNum(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value;
  throw FormatException('assessmentSubmitted.$key debe ser num.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('assessmentSubmitted.$key debe ser bool.');
}

Map<String, List<String>> _answersMap(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('assessmentSubmitted.answers debe ser objeto.');
  }
  return Map<String, List<String>>.unmodifiable(
    raw.map((key, value) {
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException(
          'assessmentSubmitted.answers.${key.toString()} debe ser string[].',
        );
      }
      return MapEntry(
        key.toString(),
        List<String>.unmodifiable(value.cast<String>()),
      );
    }),
  );
}
