import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';

final class LibraryTestSource extends OmniManualsSource {
  const LibraryTestSource();

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const <OmniManualInfo>[
    OmniManualInfo(
      id: 'install',
      title: 'Instalación',
      subtitle: 'Preparación del equipo',
      version: '1.0.0',
      languages: <String>['es', 'en'],
    ),
    OmniManualInfo(
      id: 'diagnostics',
      title: 'Diagnóstico',
      subtitle: 'Resolución de errores',
      languages: <String>['es'],
    ),
  ];
}

void main() {
  tearDown(OmniManuals.dispose);

  testWidgets('OmniLibrary muestra título, búsqueda y cards', (tester) async {
    await OmniManuals.initialize(
      config: const OmniManualsConfig(source: LibraryTestSource()),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: OmniLibrary(
          title: 'Biblioteca técnica',
          introduction: 'Selecciona un manual para continuar.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca técnica'), findsOneWidget);
    expect(find.text('Selecciona un manual para continuar.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Instalación'), findsOneWidget);
    expect(find.text('Diagnóstico'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsAtLeastNWidgets(2));
  });

  testWidgets('OmniLibrary filtra manuales por búsqueda', (tester) async {
    await OmniManuals.initialize(
      config: const OmniManualsConfig(source: LibraryTestSource()),
    );

    await tester.pumpWidget(const MaterialApp(home: OmniLibrary()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'errores');
    await tester.pumpAndSettle();

    expect(find.text('Diagnóstico'), findsOneWidget);
    expect(find.text('Instalación'), findsNothing);
  });
}
