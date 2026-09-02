/// (P203 §2) COKLU TESIS — mobil secici.
///
/// ===========================================================================
/// MOBILDE GIRIS TEK TESISE DUSER — OLCULDU
/// ===========================================================================
/// Mobil giris TELEFONLADIR ve `uq_app_user_telefon` GLOBAL benzersizdir:
/// bir numara TEK bir tesis satirina karsilik gelir. Yani "hangi tesise
/// gireyim" sorusu mobilde GIRISTE sorulamaz; kisi bir tesise girer ve
/// UYGULAMA ICINDEN gecer. Bu dosya o gecisi olcer.
///
/// Taklit EN ALTTA (HTTP adapteri): ekran -> api -> tel uzerindeki govde
/// zincirinin tamami gercektir (P200'de ogrenilen ders).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/tesis/presentation/tesis_secici_karti.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.uyelikler);

  final List<Map<String, dynamic>> uyelikler;
  final istekler = <({String yol, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : {},
    ));
    final govde = switch (options.path) {
      '/me/tesislerim' => {'tesisler': uyelikler},
      '/me/tesis-degistir' => {
          'access_token': sahteJwt({'role': 'resident', 'tenant_id': 't-2'}),
          'refresh_token': 'yenileme',
          'token_type': 'bearer',
          'expires_in': 900,
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _A = {'tenant_id': 't-1', 'slug': 'oltu', 'ad': 'Oltu Sitesi', 'rol': 'yonetici'};
const _B = {'tenant_id': 't-2', 'slug': 'city', 'ad': 'City Ambiance', 'rol': 'resident'};

Future<({BellekDepo depo, _Tel tel})> _sur(
  WidgetTester tester,
  List<Map<String, dynamic>> uyelikler,
) async {
  final tel = _Tel(uyelikler);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  // Baslangicta A tesisindeyiz (jetondaki tenant_id).
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': 'yonetici', 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const Scaffold(body: TesisSeciciKarti())),
    ),
  );
  await tester.pumpAndSettle();
  return (depo: depo, tel: tel);
}

void main() {
  testWidgets('TEK tesisliye kart HIC CIZILMEZ', (tester) async {
    // Olmayan bir karar sunmak, ayarlar ekranini gereksiz uzatirdi.
    await _sur(tester, [_A]);
    expect(find.byKey(const Key('tesis-secici-karti')), findsNothing);
  });

  testWidgets('COK tesisli: kart cikar, BULUNDUGU tesis isaretli', (tester) async {
    await _sur(tester, [_A, _B]);
    expect(find.byKey(const Key('tesis-secici-karti')), findsOneWidget);
    expect(find.text('Oltu Sitesi'), findsOneWidget);
    expect(find.text('City Ambiance'), findsOneWidget);
    // Bulundugu tesis "Buradasiniz" der; oteki ROLU gosterir.
    expect(find.text('Buradasınız'), findsOneWidget);
    // Rol metni SOZLUKTEN gelir; sabit yazmak ceviri degisince
    // sessizce eskirdi.
    expect(find.text('Site Sakini'), findsOneWidget);
  });

  testWidgets('GECIS: dogru uca, dogru govdeyle; JETON SAKLANIR', (tester) async {
    final s = await _sur(tester, [_A, _B]);
    await tester.tap(find.byKey(const Key('tesis-sec-t-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final gecis = s.tel.istekler.where((i) => i.yol == '/me/tesis-degistir');
    expect(gecis, hasLength(1));
    expect(gecis.single.govde, {'tenant_id': 't-2'});
    // YENI JETON SAKLANDI: bundan sonraki her istek YENI tesise gider.
    // Saklanmasaydi kullanici "gectim" sanip eski tesisin verisini
    // gormeye devam ederdi — sessiz ve tehlikeli.
    expect(s.depo.kutu['auth.access_token'], isNot(startsWith('yonetici')));
    expect(s.depo.kutu['auth.refresh_token'], 'yenileme');
  });

  testWidgets('BULUNDUGU tesise TIKLANAMAZ', (tester) async {
    final s = await _sur(tester, [_A, _B]);
    await tester.tap(find.byKey(const Key('tesis-sec-t-1')));
    await tester.pump();
    expect(
      s.tel.istekler.where((i) => i.yol == '/me/tesis-degistir'),
      isEmpty,
      reason: 'zaten oradasin — istek atilmamali',
    );
  });
}
