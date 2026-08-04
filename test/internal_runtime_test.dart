import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/src/internal/runtime_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runtime vive declarado como asset del package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- assets/runtime/'));
    expect(pubspec, contains('- assets/runtime/src/'));
    expect(pubspec, contains('- assets/runtime/styles/'));
    expect(File('assets/runtime/index.html').existsSync(), isTrue);
    expect(File('assets/runtime/src/manual.js').existsSync(), isTrue);
    expect(File('assets/runtime/styles/layout.css').existsSync(), isTrue);
    expect(packageRuntimeAssetRoot, 'packages/omni_manuals/assets/runtime');
  });

  test('Flutter empaqueta los assets clave del runtime canónico', () async {
    final shared = await rootBundle.loadString(
      '$packageRuntimeAssetRoot/src/components/shared.js',
    );
    final componentsCss = await rootBundle.loadString(
      '$packageRuntimeAssetRoot/styles/components.css',
    );
    final printCss = await rootBundle.loadString(
      '$packageRuntimeAssetRoot/styles/print.css',
    );
    final manual = await rootBundle.loadString(
      '$packageRuntimeAssetRoot/src/manual.js',
    );

    expect(shared, contains('overlayArrowGeometry'));
    expect(shared, contains('overlayArrowHeadPath'));
    expect(shared, isNot(contains('marker-end')));
    expect(componentsCss, contains('.annotation-arrow-head'));
    expect(printCss, contains('.annotation-marker .annotation-label'));
    expect(manual, contains('overlayArrowGeometry'));
    expect(manual, contains('overlayArrowHeadPath'));
  });

  test('runtime embebido no contiene arranque legacy de biblioteca', () {
    final runtimeRoot = Directory('assets/runtime');
    final files = runtimeRoot.listSync(recursive: true).whereType<File>().where(
      (file) {
        final path = file.path;
        return path.endsWith('.js') || path.endsWith('.html');
      },
    );

    for (final file in files) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('viewer-config.json')), reason: file.path);
      expect(
        content,
        isNot(contains('assets/omnimanual/runtime')),
        reason: file.path,
      );
      expect(
        content,
        isNot(contains('assets/omnimanual/library')),
        reason: file.path,
      );
    }
  });

  test('runtime recibe manualId e idioma por bootstrap explícito', () {
    final appConfig = File(
      'assets/runtime/src/app-config.js',
    ).readAsStringSync();
    final navigation = File(
      'assets/runtime/src/navigation.js',
    ).readAsStringSync();

    expect(appConfig, contains('parameters.get("manualId")'));
    expect(appConfig, contains('parameters.get("language")'));
    expect(appConfig, isNot(contains('parameters.get("manual")')));
    expect(appConfig, isNot(contains('parameters.get("lang")')));
    expect(navigation, contains('parameters.set("manualId"'));
    expect(navigation, contains('parameters.set("language"'));
  });

  test(
    'bootstrap directo no solicita biblioteca legacy y publica bridge state',
    () {
      final manual = File('assets/runtime/src/manual.js').readAsStringSync();
      final bootstrap = manual.substring(
        manual.indexOf('async function bootstrap'),
        manual.indexOf('bootstrap().catch'),
      );

      expect(manual, contains('async function ensureLibraryData()'));
      expect(bootstrap, isNot(contains('loadLibraryPackage')));
      expect(
        manual,
        contains('if (route.view === "manual") await renderManualRoute(route)'),
      );
      expect(manual, contains('reportBridgeState("ready"'));
      expect(manual, contains('reportBridgeState("failed"'));
      expect(manual, contains('handleBridgeRequest'));
    },
  );

  test('runtime empaquetado está sincronizado con framework/runtime', () async {
    final result = await Process.run('python3', <String>[
      '../../scripts/sync_omni_manuals_runtime.py',
      '--check',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('safeRelativePath normaliza index y bloquea escapes', () {
    expect(safeRelativePath('/'), 'index.html');
    expect(safeRelativePath('/src/app.js'), 'src/app.js');
    expect(safeRelativePath('/../secret'), isNull);
    expect(safeRelativePath('/assets//image.png'), isNull);
    expect(safeRelativePath(r'/assets\image.png'), isNull);
  });

  test('parseRangeHeader acepta rangos HTTP usados por WebView', () {
    expect(parseRangeHeader('bytes=2-5', 10)?.start, 2);
    expect(parseRangeHeader('bytes=2-5', 10)?.endInclusive, 5);
    expect(parseRangeHeader('bytes=5-', 10)?.endInclusive, 9);
    expect(parseRangeHeader('bytes=-4', 10)?.start, 6);
    expect(parseRangeHeader('items=0-1', 10), isNull);
  });

  test('mimeType cubre runtime, JSON, imagen y vídeo', () {
    expect(mimeType('index.html'), startsWith('text/html'));
    expect(mimeType('src/manual.js'), startsWith('text/javascript'));
    expect(
      mimeType('manuals/5f95393e-a090-45a7-b814-89f1b13646e1/manual.json'),
      startsWith('application/json'),
    );
    expect(mimeType('assets/images/common/cover.jpg'), 'image/jpeg');
    expect(mimeType('assets/videos/demo.mp4'), 'video/mp4');
  });
}
