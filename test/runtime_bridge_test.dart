import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';
import 'package:omni_manuals/src/internal/runtime_bridge.dart';

void main() {
  test('bridge exposes deterministic runtime action contract', () {
    final openSearch = RuntimeBridgeScripts.invoke(
      'openSearch-1',
      'openSearch',
    );

    final openTableOfContents = RuntimeBridgeScripts.invoke(
      'openTableOfContents-1',
      'openTableOfContents',
    );

    final setLocale = RuntimeBridgeScripts.invoke(
      'setLocale-1',
      'setLocale',
      const <String, Object?>{'language': 'es'},
    );

    expect(openSearch, contains('handleBridgeRequest'));
    expect(openSearch, contains('"openSearch-1"'));
    expect(openSearch, contains('"openSearch"'));

    expect(openTableOfContents, contains('"openTableOfContents"'));

    expect(setLocale, contains('"setLocale"'));
    expect(setLocale, contains('"language":"es"'));
  });

  test('bridge locale script escapes language safely', () {
    final script = RuntimeBridgeScripts.invoke(
      'setLocale-1',
      'setLocale',
      const <String, Object?>{'language': 'en-US'},
    );

    expect(script, contains('"language":"en-US"'));
    expect(script, isNot(contains("'en-US'")));
  });

  test('bridge returns typed success results', () async {
    final scripts = <String>[];

    final bridge = RuntimeBridge.withRunner((script) async {
      scripts.add(script);
    })..updateState(RuntimeBridgeState.ready);

    final resultFuture = bridge.openSearch();

    bridge.handleMessage(
      jsonEncode({
        'type': 'actionResult',
        'requestId': 'openSearch-1',
        'result': {
          'ok': true,
          'command': 'openSearch',
          'detail': {'source': 'test'},
        },
      }),
    );

    final result = await resultFuture;

    expect(scripts, hasLength(1));
    expect(scripts.single, contains('"openSearch"'));

    expect(result.ok, isTrue);
    expect(result.command, 'openSearch');
    expect(result.detail['source'], 'test');
  });

  test('bridge table of contents returns typed success results', () async {
    final scripts = <String>[];

    final bridge = RuntimeBridge.withRunner((script) async {
      scripts.add(script);
    })..updateState(RuntimeBridgeState.ready);

    final resultFuture = bridge.openTableOfContents();

    bridge.handleMessage(
      jsonEncode({
        'type': 'actionResult',
        'requestId': 'openTableOfContents-1',
        'result': {
          'ok': true,
          'command': 'openTableOfContents',
          'detail': <String, Object?>{},
        },
      }),
    );

    final result = await resultFuture;

    expect(scripts, hasLength(1));
    expect(scripts.single, contains('"openTableOfContents"'));

    expect(result.ok, isTrue);
    expect(result.command, 'openTableOfContents');
  });

  test('bridge setLocale returns typed success results', () async {
    final scripts = <String>[];

    final bridge = RuntimeBridge.withRunner((script) async {
      scripts.add(script);
    })..updateState(RuntimeBridgeState.ready);

    final resultFuture = bridge.setLocale('en');

    bridge.handleMessage(
      jsonEncode({
        'type': 'actionResult',
        'requestId': 'setLocale-1',
        'result': {
          'ok': true,
          'command': 'setLocale',
          'detail': {'language': 'en'},
        },
      }),
    );

    final result = await resultFuture;

    expect(scripts, hasLength(1));
    expect(scripts.single, contains('"setLocale"'));
    expect(scripts.single, contains('"language":"en"'));

    expect(result.ok, isTrue);
    expect(result.command, 'setLocale');
    expect(result.detail['language'], 'en');
  });

  test('bridge rejects invalid runtime action responses', () async {
    final bridge = RuntimeBridge.withRunner((script) async {})
      ..updateState(RuntimeBridgeState.ready);

    final resultFuture = bridge.openSearch();

    bridge.handleMessage(
      jsonEncode({
        'type': 'actionResult',
        'requestId': 'openSearch-1',

        // Debe ser un objeto con ok y command.
        'result': true,
      }),
    );

    await expectLater(
      resultFuture,
      throwsA(
        isA<OmniManualsException>().having(
          (error) => error.code,
          'code',
          OmniManualsErrorCode.webviewLoadFailed,
        ),
      ),
    );
  });

  test('bridge surfaces runtime action failures deterministically', () async {
    final bridge = RuntimeBridge.withRunner((script) async {})
      ..updateState(RuntimeBridgeState.ready);

    final resultFuture = bridge.openSearch();

    bridge.handleMessage(
      jsonEncode({
        'type': 'actionResult',
        'requestId': 'openSearch-1',
        'result': {
          'ok': false,
          'command': 'openSearch',
          'code': 'runtime_not_ready',
          'message': 'Runtime state is loading.',
        },
      }),
    );

    await expectLater(
      resultFuture,
      throwsA(
        isA<OmniManualsException>()
            .having(
              (error) => error.code,
              'code',
              OmniManualsErrorCode.webviewLoadFailed,
            )
            .having(
              (error) => error.context,
              'context',
              containsPair('runtimeCode', 'runtime_not_ready'),
            ),
      ),
    );
  });

  test('bridge preserves real JavaScript runner errors as cause', () async {
    final cause = StateError('js bridge failed');

    final bridge = RuntimeBridge.withRunner((script) async {
      throw cause;
    })..updateState(RuntimeBridgeState.ready);

    await expectLater(
      bridge.openSearch(),
      throwsA(
        isA<OmniManualsException>().having(
          (error) => error.cause,
          'cause',
          same(cause),
        ),
      ),
    );
  });

  test(
    'bridge ignores actions during loading without invoking WebView',
    () async {
      var calls = 0;

      final bridge = RuntimeBridge.withRunner((script) async {
        calls += 1;
      });

      final result = await bridge.openSearch();

      expect(result.ignored, isTrue);
      expect(calls, 0);
    },
  );

  test('bridge handles typed runtime state messages', () {
    final bridge = RuntimeBridge.withRunner((script) async {});

    expect(
      bridge.handleMessage('{"type":"state","state":"ready"}'),
      RuntimeBridgeState.ready,
    );

    expect(bridge.state, RuntimeBridgeState.ready);

    expect(
      bridge.handleMessage('{"type":"state","state":"failed"}'),
      RuntimeBridgeState.failed,
    );

    expect(bridge.state, RuntimeBridgeState.failed);
  });

  test('bridge remains compatible with legacy state messages', () {
    final bridge = RuntimeBridge.withRunner((script) async {});

    expect(bridge.handleMessage('{"state":"ready"}'), RuntimeBridgeState.ready);

    expect(bridge.state, RuntimeBridgeState.ready);
  });

  test('bridge state parser accepts runtime protocol messages', () {
    expect(
      runtimeBridgeStateFromMessage('{"type":"state","state":"loading"}'),
      RuntimeBridgeState.loading,
    );

    expect(
      runtimeBridgeStateFromMessage('{"type":"state","state":"ready"}'),
      RuntimeBridgeState.ready,
    );

    expect(
      runtimeBridgeStateFromMessage('{"type":"state","state":"failed"}'),
      RuntimeBridgeState.failed,
    );

    expect(
      runtimeBridgeStateFromMessage('{"type":"state","state":"closing"}'),
      RuntimeBridgeState.closing,
    );

    expect(
      runtimeBridgeStateFromMessage('{"type":"state","state":"disposed"}'),
      RuntimeBridgeState.disposed,
    );

    expect(
      runtimeBridgeStateFromMessage('not-json'),
      RuntimeBridgeState.loading,
    );
  });

  test('bridge ignores unknown action result request IDs', () {
    final bridge = RuntimeBridge.withRunner((script) async {})
      ..updateState(RuntimeBridgeState.ready);

    expect(
      () => bridge.handleMessage(
        jsonEncode({
          'type': 'actionResult',
          'requestId': 'unknown-request',
          'result': {'ok': true, 'command': 'openSearch'},
        }),
      ),
      returnsNormally,
    );
  });

  test(
    'bridge dispose is idempotent and rejects actions after dispose',
    () async {
      var calls = 0;

      final bridge = RuntimeBridge.withRunner((script) async {
        calls += 1;
      });

      bridge
        ..updateState(RuntimeBridgeState.ready)
        ..dispose()
        ..dispose()
        ..updateState(RuntimeBridgeState.ready);

      final result = await bridge.openSearch();

      expect(bridge.isDisposed, isTrue);
      expect(result.ignored, isTrue);
      expect(calls, 0);
    },
  );

  test(
    'bridge completes pending actions as ignored when closing starts',
    () async {
      final scriptStarted = Completer<void>();

      final bridge = RuntimeBridge.withRunner((script) async {
        if (!scriptStarted.isCompleted) {
          scriptStarted.complete();
        }
      });

      bridge.updateState(RuntimeBridgeState.ready);

      final action = bridge.openTableOfContents();

      await scriptStarted.future;

      bridge.markClosing();

      final result = await action;

      expect(bridge.state, RuntimeBridgeState.closing);
      expect(result.ignored, isTrue);

      bridge.dispose();
      expect(bridge.isDisposed, isTrue);
    },
  );

  test('bridge completes pending actions as ignored when disposed', () async {
    final scriptStarted = Completer<void>();

    final bridge = RuntimeBridge.withRunner((script) async {
      if (!scriptStarted.isCompleted) {
        scriptStarted.complete();
      }
    });

    bridge.updateState(RuntimeBridgeState.ready);

    final action = bridge.openSearch();

    await scriptStarted.future;

    bridge.dispose();

    final result = await action;

    expect(bridge.isDisposed, isTrue);
    expect(result.ignored, isTrue);
  });
}
