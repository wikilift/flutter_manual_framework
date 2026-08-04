import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';

final class PageTestSource extends OmniManualsSource {
  const PageTestSource();

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[
    OmniManualInfo(
      id: 'demo_manual',
      title: 'Demo manual',
      subtitle: 'Manual de prueba',
      languages: <String>['es', 'en'],
    ),
    OmniManualInfo(
      id: 'second_manual',
      title: 'Second manual',
      languages: <String>['es'],
    ),
  ];
}

final class CollectionPageTestSource extends OmniManualsSource {
  const CollectionPageTestSource();

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[
    OmniManualInfo(id: 'demo_manual', title: 'Demo manual'),
    OmniManualInfo(id: 'second_manual', title: 'Second manual'),
  ];

  @override
  Future<List<OmniLibraryEntry>> loadLibraryEntries() async =>
      <OmniLibraryEntry>[
        OmniCollectionEntry(
          id: 'controllers',
          title: 'Controladores',
          children: <OmniLibraryEntry>[
            OmniManualLibraryEntry(
              manual: const OmniManualInfo(
                id: 'demo_manual',
                title: 'Demo manual',
              ),
            ),
            OmniCollectionEntry(
              id: 'advanced',
              title: 'Avanzado',
              children: <OmniLibraryEntry>[
                OmniManualLibraryEntry(
                  manual: const OmniManualInfo(
                    id: 'second_manual',
                    title: 'Second manual',
                  ),
                ),
              ],
            ),
          ],
        ),
      ];
}

void main() {
  tearDown(OmniManuals.dispose);

  Future<void> initialize() => OmniManuals.initialize(
    config: const OmniManualsConfig(
      defaultLanguage: 'es',
      source: PageTestSource(),
    ),
  );

  testWidgets('biblioteca raíz no muestra botón atrás', (tester) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: OmniManualsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Omni Manuals'), findsWidgets);
    expect(find.byType(BackButtonIcon), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('biblioteca en ruta secundaria muestra atrás de Navigator', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OmniManualsPage(),
                ),
              );
            },
            child: const Text('Open SDK'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open SDK'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButtonIcon), findsOneWidget);
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Open SDK'), findsOneWidget);
  });

  testWidgets('biblioteca embebible no impone Scaffold ni AppBar', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: OmniManualsLibrary()));
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Demo manual'), findsOneWidget);
    expect(find.text('Second manual'), findsOneWidget);
  });

  testWidgets('callback de selección desactiva navegación automática', (
    tester,
  ) async {
    await initialize();
    OmniManualInfo? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmniManualsLibrary(
            onManualSelected: (context, manual) => selected = manual,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo manual'));
    await tester.pump();

    expect(selected?.id, 'demo_manual');
    expect(find.byType(OmniManualViewerPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('colecciones navegan con breadcrumbs y back interno', (
    tester,
  ) async {
    await OmniManuals.initialize(
      config: const OmniManualsConfig(source: CollectionPageTestSource()),
    );

    await tester.pumpWidget(const MaterialApp(home: OmniManualsLibrary()));
    await tester.pumpAndSettle();

    expect(find.text('Controladores'), findsOneWidget);
    await tester.tap(find.text('Controladores'));
    await tester.pumpAndSettle();

    expect(find.text('Demo manual'), findsOneWidget);
    expect(find.text('Avanzado'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);

    await tester.tap(find.text('Avanzado'));
    await tester.pumpAndSettle();
    expect(find.text('Second manual'), findsOneWidget);

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Controladores'), findsOneWidget);
  });

  testWidgets('biblioteca no desborda en pantalla pequeña y texto escalado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const OmniManualsPage(
          introduction:
              'Texto de introducción deliberadamente largo para validar el layout.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose desmonta la página sin lanzar errores', (tester) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: OmniManualsPage()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
