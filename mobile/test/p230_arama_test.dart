/// (P230 §3) MOBIL GENEL ARAMA.
///
/// Web'de ustte bir arama kutusu var; mobilde YOKTU. Menuyu ezbere
/// bilmeyen kullanici icin tek yol ekran ekran gezmekti.
///
/// YENI UC ACILMADI: `GET /arama?q=` zaten vardi (17 kaynak, rol suzgeci
/// SUNUCUDA). Ikinci bir uc, rol kumelerinin IKINCI bir kopyasi demekti.
///
/// TAKLIT HTTP ADAPTER'INDA (P200 dersi).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/arama/data/arama_api.dart';
import 'package:mobile/src/features/arama/presentation/arama_screen.dart';

import 'helpers/l10n_test_app.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  final List<Uri> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _yanit(List<Map<String, dynamic>> items) => {
  'q': 'x',
  'items': items,
};

({AramaApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body);
  dio.httpClientAdapter = adapter;
  return (api: AramaApi(dio), adapter: adapter);
}

Widget _ekran(AramaApi api, {Locale locale = const Locale('tr')}) =>
    ProviderScope(
      overrides: [aramaApiProvider.overrideWithValue(api)],
      child: l10nApp(const AramaScreen(), locale: locale),
    );

void main() {
  group('API sozlesmesi', () {
    test('DOGRU UCA ve `q` ile gider', () async {
      final (api: api, adapter: adapter) = _kur(_yanit([]));
      await api.ara('cop sutu');
      final uri = adapter.istekler.single;
      expect(uri.path, '/arama');
      expect(uri.queryParameters['q'], 'cop sutu');
    });

    test('vurus alanlari cozulur', () async {
      final (api: api, adapter: _) = _kur(_yanit([
        {
          'kaynak': 'daire',
          'id': 'd1',
          'baslik': 'A-12',
          'ayrinti': 'A Blok',
        }
      ]));
      final v = (await api.ara('a-12')).single;
      expect(v.kaynak, 'daire');
      expect(v.baslik, 'A-12');
      expect(v.ayrinti, 'A Blok');
    });
  });

  group('ekran', () {
    testWidgets('IKI HARFTEN KISA yazimda istek ATILMAZ', (tester) async {
      // Tek harf butun tesisi tarar; sunucu da 422 veriyor. Istemci ayni
      // esigi uygulamazsa her tek harfte bosuna bir hata alinirdi.
      final (api: api, adapter: adapter) = _kur(_yanit([]));
      await tester.pumpWidget(_ekran(api));
      await tester.enterText(find.byKey(const Key('arama-alani')), 'a');
      await tester.pump(const Duration(milliseconds: 600));
      expect(adapter.istekler, isEmpty);
    });

    testWidgets('GECIKMELI: her tusta istek atilmaz', (tester) async {
      final (api: api, adapter: adapter) = _kur(_yanit([]));
      await tester.pumpWidget(_ekran(api));
      final alan = find.byKey(const Key('arama-alani'));
      await tester.enterText(alan, 'co');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(alan, 'cop');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(alan, 'cop s');
      expect(adapter.istekler, isEmpty, reason: 'gecikme dolmadan istek gitti');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(adapter.istekler.length, 1, reason: 'tek istek bekleniyordu');
    });

    testWidgets('SONUC YOKSA "bulunamadi" DER', (tester) async {
      // Bos liste, kullaniciya aramanin CALISMADIGI izlenimi verirdi.
      final (api: api, adapter: _) = _kur(_yanit([]));
      await tester.pumpWidget(_ekran(api));
      await tester.enterText(find.byKey(const Key('arama-alani')), 'zzzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('arama-bos')), findsOneWidget);
    });

    testWidgets('SONUC cizilir ve kaynak adi YERELLESTIRILIR',
        (tester) async {
      // Sunucu KIMLIK doner (`daire`), metin DEGIL: ayni sonuc yedi dilde
      // farkli yazilir.
      final (api: api, adapter: _) = _kur(_yanit([
        {'kaynak': 'daire', 'id': 'd1', 'baslik': 'A-12', 'ayrinti': null}
      ]));
      await tester.pumpWidget(_ekran(api, locale: const Locale('en')));
      await tester.enterText(find.byKey(const Key('arama-alani')), 'a-12');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('A-12'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
    });

    testWidgets('EKRANI OLMAYAN kaynak GIZLENMEZ, dokunmasi kapatilir',
        (tester) async {
      // Sonucu gizlemek "kayit yok" izlenimi verirdi ki bu YANLIS: kayit
      // var, mobilde gosterilecek ekran yok.
      final (api: api, adapter: _) = _kur(_yanit([
        {'kaynak': 'icra', 'id': 'i1', 'baslik': 'Icra dosyasi', 'ayrinti': null}
      ]));
      await tester.pumpWidget(_ekran(api));
      await tester.enterText(find.byKey(const Key('arama-alani')), 'icra');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final karo = tester.widget<ListTile>(
          find.byKey(const Key('arama-sonuc-i1')));
      expect(find.text('Icra dosyasi'), findsOneWidget);
      expect(karo.enabled, isFalse);
    });
  });
}
