import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../errors.dart';
import '../events.dart';
import 'runtime_paths.dart';

typedef RuntimeScriptRunner = Future<void> Function(String script);
typedef RuntimeEventHandler = void Function(OmniManualsEvent event);

final class RuntimeBridgeScripts {
  const RuntimeBridgeScripts._();

  static const String state = 'window.OmniManual?.getState?.() ?? {}';

  static String invoke(
    String requestId,
    String command, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) {
    final encodedRequestId = jsonEncode(requestId);
    final encodedCommand = jsonEncode(command);
    final encodedPayload = jsonEncode(payload);

    return '''
(() => {
  const requestId = $encodedRequestId;
  const command = $encodedCommand;
  const payload = $encodedPayload;
  const api = window.OmniManual;

  if (!api?.handleBridgeRequest) {
    window.OmniManualBridge?.postMessage?.(
      JSON.stringify({
        type: "actionResult",
        requestId,
        result: {
          ok: false,
          command,
          code: "bridge_unavailable",
          message: "window.OmniManual.handleBridgeRequest is not available",
          detail: {}
        }
      })
    );
    return;
  }

  void api.handleBridgeRequest(requestId, command, payload);
})()
''';
  }

  static String reloadCurrent({String? sectionId}) {
    final encodedSectionId = jsonEncode(sectionId);

    return '''
(() => {
  const api = window.OmniManual;
  const currentState = api?.getState?.() ?? {};

  if (!api?.reloadCurrent) {
    return;
  }

  void api.reloadCurrent({
    preserveSection: true,
    sectionId: $encodedSectionId ?? currentState.sectionId,
    scrollY: window.scrollY
  });
})()
''';
  }
}

enum RuntimeBridgeState { loading, ready, failed, closing, disposed }

@immutable
final class RuntimeBridgeActionResult {
  const RuntimeBridgeActionResult({
    required this.ok,
    required this.command,
    this.code,
    this.message,
    this.detail = const <String, Object?>{},
    this.ignored = false,
  });

  factory RuntimeBridgeActionResult.fromJson(
    String expectedCommand,
    Map<String, Object?> json,
  ) {
    final ok = json['ok'];
    final command = json['command'];

    if (ok is! bool || command is! String || command.isEmpty) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.webviewLoadFailed,
        message: 'Respuesta inválida del bridge del runtime.',
        context: json,
        recoveryHint:
            'El runtime debe devolver JSON con ok:boolean y command:string.',
      );
    }

    if (command != expectedCommand) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.webviewLoadFailed,
        message: 'Respuesta del bridge no coincide con la acción solicitada.',
        context: <String, Object?>{
          'expected': expectedCommand,
          'actual': command,
        },
      );
    }

    final detail = json['detail'];

    return RuntimeBridgeActionResult(
      ok: ok,
      command: command,
      code: json['code'] is String ? json['code'] as String : null,
      message: json['message'] is String ? json['message'] as String : null,
      detail: detail is Map
          ? Map<String, Object?>.unmodifiable(
              detail.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const <String, Object?>{},
    );
  }

  factory RuntimeBridgeActionResult.ignored(
    String command,
    RuntimeBridgeState state,
  ) {
    return RuntimeBridgeActionResult(
      ok: true,
      command: command,
      code: 'ignored',
      message: 'Bridge action ignored because state=${state.name}.',
      ignored: true,
    );
  }

  final bool ok;
  final String command;
  final String? code;
  final String? message;
  final Map<String, Object?> detail;
  final bool ignored;
}

final class _PendingRuntimeAction {
  const _PendingRuntimeAction({required this.command, required this.completer});

  final String command;
  final Completer<RuntimeBridgeActionResult> completer;
}

final class RuntimeBridge extends ChangeNotifier {
  RuntimeBridge(
    WebViewController controller, {
    RuntimeEventHandler? onRuntimeEvent,
  }) : this.withRunner(
         controller.runJavaScript,
         runtimeEventHandler: onRuntimeEvent,
       );

  @visibleForTesting
  RuntimeBridge.withRunner(
    this._runner, {
    RuntimeEventHandler? runtimeEventHandler,
  }) : _onRuntimeEvent = runtimeEventHandler;

  static const Duration _actionTimeout = Duration(seconds: 15);

  final RuntimeScriptRunner _runner;
  final RuntimeEventHandler? _onRuntimeEvent;

  final Map<String, _PendingRuntimeAction> _pendingActions =
      <String, _PendingRuntimeAction>{};

  RuntimeBridgeState _state = RuntimeBridgeState.loading;
  int _requestSequence = 0;

  RuntimeBridgeState get state => _state;

  bool get isReady => _state == RuntimeBridgeState.ready;

  bool get isClosing => _state == RuntimeBridgeState.closing;

  bool get isDisposed => _state == RuntimeBridgeState.disposed;

  Future<RuntimeBridgeActionResult> openSearch() {
    return _run('openSearch', const <String, Object?>{});
  }

  Future<RuntimeBridgeActionResult> openTableOfContents() {
    return _run('openTableOfContents', const <String, Object?>{});
  }

  Future<RuntimeBridgeActionResult> setLocale(String language) {
    if (!isSafeLanguageCode(language)) {
      throw OmniManualsException(
        code: OmniManualsErrorCode.languageUnavailable,
        message: 'Idioma no seguro para el runtime: $language',
        context: language,
      );
    }

    return _run('setLocale', <String, Object?>{'language': language});
  }

  Future<RuntimeBridgeActionResult> _run(
    String action,
    Map<String, Object?> payload,
  ) async {
    if (_state != RuntimeBridgeState.ready) {
      _logRejectedAction(action);
      return RuntimeBridgeActionResult.ignored(action, _state);
    }

    final requestId = '$action-${++_requestSequence}';
    final completer = Completer<RuntimeBridgeActionResult>();

    _pendingActions[requestId] = _PendingRuntimeAction(
      command: action,
      completer: completer,
    );

    try {
      final script = RuntimeBridgeScripts.invoke(requestId, action, payload);

      await _runner(script);

      final result = await completer.future.timeout(
        _actionTimeout,
        onTimeout: () {
          throw OmniManualsException(
            code: OmniManualsErrorCode.webviewLoadFailed,
            message: 'El runtime no respondió a la acción solicitada.',
            context: <String, Object?>{
              'action': action,
              'requestId': requestId,
            },
            recoveryHint:
                'Comprueba que OmniManual.handleBridgeRequest publica un actionResult.',
          );
        },
      );

      if (!result.ok) {
        throw OmniManualsException(
          code: OmniManualsErrorCode.webviewLoadFailed,
          message: result.message ?? 'La acción del runtime falló.',
          context: <String, Object?>{
            'action': action,
            'requestId': requestId,
            if (result.code != null) 'runtimeCode': result.code,
            if (result.detail.isNotEmpty) 'detail': result.detail,
          },
          recoveryHint:
              'Comprueba que el runtime embebido implementa correctamente la acción solicitada.',
        );
      }

      return result;
    } catch (error) {
      if (_state == RuntimeBridgeState.closing ||
          _state == RuntimeBridgeState.disposed) {
        _logRejectedAction(action);
        return RuntimeBridgeActionResult.ignored(action, _state);
      }

      if (error is OmniManualsException) {
        rethrow;
      }

      throw OmniManualsException(
        code: OmniManualsErrorCode.webviewLoadFailed,
        message: 'No se pudo ejecutar una acción del runtime embebido.',
        cause: error,
        context: <String, Object?>{'action': action, 'requestId': requestId},
        recoveryHint:
            'Comprueba que el runtime está cargado y soporta el bridge solicitado.',
      );
    } finally {
      _pendingActions.remove(requestId);
    }
  }

  /// Procesa cualquier mensaje recibido mediante OmniManualBridge.
  ///
  /// Devuelve un estado únicamente cuando el mensaje representa un cambio
  /// de estado. Las respuestas de acciones devuelven null.
  RuntimeBridgeState? handleMessage(String rawMessage) {
    if (_state == RuntimeBridgeState.disposed) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawMessage);

      if (decoded is! Map) {
        debugPrint('[OmniManuals] ignored invalid bridge message: $rawMessage');
        return null;
      }

      final message = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final type = message['type'];

      if (type == 'actionResult') {
        _handleActionResult(message);
        return null;
      }

      if (type == 'assessmentSubmitted') {
        _handleAssessmentSubmitted(message);
        return null;
      }

      // Compatibilidad con mensajes antiguos sin type:
      // {"state":"ready","detail":{...}}
      if (type == 'state' || message.containsKey('state')) {
        final nextState = _stateFromValue(message['state']);
        updateState(nextState);
        return nextState;
      }

      debugPrint('[OmniManuals] ignored unknown bridge message: $message');
      return null;
    } catch (error, stackTrace) {
      debugPrint(
        '[OmniManuals] failed to parse bridge message: $error\n'
        '$stackTrace',
      );
      return null;
    }
  }

  void _handleAssessmentSubmitted(Map<String, Object?> message) {
    try {
      final result = OmniAssessmentResult.fromJson(message);
      _onRuntimeEvent?.call(
        OmniManualsEvent(
          type: OmniManualsEventType.assessmentSubmitted,
          manualId: result.manualId,
          assessmentResult: result,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[OmniManuals] ignored invalid assessmentSubmitted message: $error\n'
        '$stackTrace',
      );
    }
  }

  void _handleActionResult(Map<String, Object?> message) {
    final requestId = message['requestId'];

    if (requestId is! String || requestId.isEmpty) {
      debugPrint(
        '[OmniManuals] ignored actionResult without requestId: $message',
      );
      return;
    }

    final pending = _pendingActions[requestId];

    if (pending == null) {
      debugPrint(
        '[OmniManuals] ignored actionResult for unknown request: $requestId',
      );
      return;
    }

    if (pending.completer.isCompleted) {
      return;
    }

    final rawResult = message['result'];

    if (rawResult is! Map) {
      pending.completer.completeError(
        OmniManualsException(
          code: OmniManualsErrorCode.webviewLoadFailed,
          message: 'Respuesta inválida del bridge del runtime.',
          context: <String, Object?>{
            'requestId': requestId,
            'message': message,
          },
          recoveryHint: 'actionResult debe incluir un objeto result válido.',
        ),
      );
      return;
    }

    try {
      final result = RuntimeBridgeActionResult.fromJson(
        pending.command,
        rawResult.map((key, value) => MapEntry(key.toString(), value)),
      );

      pending.completer.complete(result);
    } catch (error, stackTrace) {
      pending.completer.completeError(error, stackTrace);
    }
  }

  void markClosing() {
    if (_state == RuntimeBridgeState.disposed ||
        _state == RuntimeBridgeState.closing) {
      return;
    }

    updateState(RuntimeBridgeState.closing);
    _completePendingAsIgnored(RuntimeBridgeState.closing);
  }

  void updateState(RuntimeBridgeState nextState) {
    if (_state == RuntimeBridgeState.disposed) {
      return;
    }

    if (_state == nextState) {
      return;
    }

    debugPrint(
      '[OmniManuals] bridge state: ${_state.name} -> ${nextState.name}',
    );

    _state = nextState;
    notifyListeners();
  }

  void _completePendingAsIgnored(RuntimeBridgeState state) {
    for (final pending in _pendingActions.values) {
      if (pending.completer.isCompleted) {
        continue;
      }

      pending.completer.complete(
        RuntimeBridgeActionResult.ignored(pending.command, state),
      );
    }

    _pendingActions.clear();
  }

  void _logRejectedAction(String action) {
    final reason = _state == RuntimeBridgeState.disposed
        ? 'after dispose'
        : 'because state=${_state.name}';

    debugPrint('[OmniManuals] bridge action rejected $reason: $action');
  }

  @override
  void dispose() {
    if (_state == RuntimeBridgeState.disposed) {
      return;
    }

    debugPrint('[OmniManuals] bridge dispose requested');

    _state = RuntimeBridgeState.disposed;
    _completePendingAsIgnored(RuntimeBridgeState.disposed);

    debugPrint('[OmniManuals] bridge disposed');

    super.dispose();
  }
}

RuntimeBridgeState _stateFromValue(Object? value) {
  return switch (value) {
    'ready' => RuntimeBridgeState.ready,
    'failed' => RuntimeBridgeState.failed,
    'closing' => RuntimeBridgeState.closing,
    'disposed' => RuntimeBridgeState.disposed,
    _ => RuntimeBridgeState.loading,
  };
}

RuntimeBridgeState runtimeBridgeStateFromMessage(String value) {
  try {
    final decoded = jsonDecode(value);

    if (decoded is! Map) {
      return RuntimeBridgeState.loading;
    }

    return _stateFromValue(decoded['state']);
  } catch (_) {
    return RuntimeBridgeState.loading;
  }
}
