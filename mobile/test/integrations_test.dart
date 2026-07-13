import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/integrations/data/integration_api.dart';
import 'package:mobile/src/features/integrations/domain/integration_models.dart';
import 'package:mobile/src/features/integrations/presentation/integrations_screen.dart';

/// Aga cikmayan sahte istemci.
class _FakeIntegrationApi extends IntegrationApi {
  _FakeIntegrationApi(this._items) : super(Dio());

  final List<Integration> _items;
  final List<String> triggered = [];
  TriggerResult result = const TriggerResult(ok: true, status: 200);

  @override
  Future<List<Integration>> fetchAll() async => _items;

  @override
  Future<List<IntegrationPreset>> fetchPresets() async => const [];

  @override
  Future<TriggerResult> trigger(String id,
      {String message = '', String title = ''}) async {
    triggered.add(id);
    return result;
  }
}

Integration _i({String id = 'i-1', bool secretSet = true}) => Integration(
      id: id,
      ad: 'Megafon',
      channelType: 'megaphone',
      endpointUrl: 'https://example.com/hook',
      httpMethod: 'POST',
      authType: 'bearer',
      authSecretSet: secretSet,
      payloadTemplate: '{"announcement": "{{message}}"}',
      aktif: true,
    );

(_FakeIntegrationApi, Widget) _app(List<Integration> items) {
  final api = _FakeIntegrationApi(items);
  return (
    api,
    ProviderScope(
      overrides: [integrationApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: IntegrationsScreen()),
    ),
  );
}

void main() {
  group('Integration domain', () {
    test('fromJson sir DONMEZ; auth_secret_set okunur', () {
      final it = Integration.fromJson(const {
        'id': 'i-1',
        'ad': 'Webhook',
        'channel_type': 'webhook',
        'endpoint_url': 'https://x/y',
        'http_method': 'POST',
        'headers_json': {'Content-Type': 'application/json'},
        'auth_type': 'api_key',
        'auth_secret_set': true,
        'payload_template': '{"text": "{{message}}"}',
        'aktif': true,
      });
      expect(it.authSecretSet, isTrue);
      expect(it.channelType, 'webhook');
      expect(it.headersJson['Content-Type'], 'application/json');
    });

    test('draft.toJson: authSecret YALNIZ doluysa gonderilir (write-only)', () {
      const bos = IntegrationDraft(
        ad: 'x',
        channelType: 'webhook',
        endpointUrl: 'https://x/y',
        httpMethod: 'POST',
        authType: 'none',
        payloadTemplate: '',
        aktif: true,
      );
      expect(bos.toJson().containsKey('auth_secret'), isFalse);
      const dolu = IntegrationDraft(
        ad: 'x',
        channelType: 'webhook',
        endpointUrl: 'https://x/y',
        httpMethod: 'POST',
        authType: 'bearer',
        authSecret: 'tok',
        payloadTemplate: '',
        aktif: true,
      );
      expect(dolu.toJson()['auth_secret'], 'tok');
    });
  });

  group('IntegrationsScreen (yonetici)', () {
    testWidgets('liste + "Test" tetikler ve sonucu gosterir', (tester) async {
      final (api, app) = _app([_i()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Megafon'), findsOneWidget);
      // sir kayitli isareti
      expect(find.textContaining('🔒'), findsOneWidget);

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(api.triggered, ['i-1']);
      expect(find.textContaining('Başarılı'), findsOneWidget);
    });

    testWidgets('Test basarisiz (SSRF/ag) -> hata sonucu gosterilir',
        (tester) async {
      final (api, app) = _app([_i()]);
      api.result = const TriggerResult(
        ok: false,
        error: 'Hedef adres engellendi (ozel/ic ag veya cozulemedi).',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('engellendi'), findsOneWidget);
    });

    testWidgets('bos liste anlamli mesaj', (tester) async {
      final (_, app) = _app(const []);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('Entegrasyon yok'), findsOneWidget);
    });
  });
}
