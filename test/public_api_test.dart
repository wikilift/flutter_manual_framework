import 'package:flutter_test/flutter_test.dart';
import 'package:omni_manuals/omni_manuals.dart';
import 'package:omni_manuals/src/internal/sdk_controller.dart';

final class FakeSource extends OmniManualsSource {
  const FakeSource();

  @override
  Future<List<OmniManualInfo>> loadManuals() async => const [
    OmniManualInfo(
      id: 'demo_manual',
      title: 'Demo manual',
      languages: ['es', 'en'],
      version: '1.0.0',
      minimumRuntimeVersion: '1.8.5',
    ),
  ];
}

void main() {
  tearDown(OmniManuals.dispose);

  test('initialize carga catálogo público desde provider', () async {
    await OmniManuals.initialize(
      config: const OmniManualsConfig(source: FakeSource()),
    );

    expect(OmniManuals.state, OmniManualsState.ready);
    expect(OmniManuals.manuals.single.id, 'demo_manual');
    expect(OmniManuals.manual('demo_manual').title, 'Demo manual');
  });

  test('manual inexistente produce error público accionable', () async {
    await OmniManuals.initialize(
      config: const OmniManualsConfig(source: FakeSource()),
    );

    expect(
      () => OmniManuals.manual('missing'),
      throwsA(
        isA<OmniManualsException>().having(
          (error) => error.code,
          'code',
          OmniManualsErrorCode.manualNotFound,
        ),
      ),
    );
  });

  test('manualUri construye apertura directa con query canónica', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final controller = OmniManualsController();
    addTearDown(controller.dispose);

    await controller.initialize(
      config: OmniManualsConfig(
        source: FakeSource(),
        defaultLanguage: 'es',
        publicApiBaseUrl: Uri.parse('https://manuals.example.com/'),
      ),
    );

    final uri = await controller.manualUri(id: 'demo_manual', embedded: true);

    expect(uri.queryParameters['manualId'], 'demo_manual');
    expect(uri.queryParameters['language'], 'es');
    expect(uri.queryParameters['shell'], 'embedded');
    expect(uri.queryParameters['publicApiBaseUrl'], 'https://manuals.example.com/');
    expect(uri.queryParameters.containsKey('manual'), isFalse);
    expect(uri.queryParameters.containsKey('lang'), isFalse);
  });
}
