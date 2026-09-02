/// (P206 §4.2/§4.5) MOBIL PERSONEL EKLEME (e-posta) + SAYAC OKUMA.
///
/// ===========================================================================
/// OLCULEN KUSUR — PERSONEL EKLEME KIRIKTI
/// ===========================================================================
/// Mobilin gonderdigi govde (`ad`+`telefon`+`role`) dev API'de **422**
/// aliyordu: `{"field":"email","message":"Field required"}`. P197'den
/// beri `app_user.email` NOT NULL (goc 0089) — yani mobil personel
/// ekleme O TURDAN BERI CALISMIYORDU ve P204 paritesinde "tam" diye
/// isaretlenmisti. Bu dosya e-postanin GOVDEDE gittigini kilitler.
///
/// Taklit HTTP adapter'inda (P200 dersi).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/finans/presentation/sayac_okuma_screen.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, String metot, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final govde = switch (options.path) {
      '/users' => options.method == 'POST'
          ? {'id': 'yeni-1'}
          : {'items': <Map<String, dynamic>>[], 'meta': {'total': 0}},
      '/sayaclar/ana' => {
          'items': [
            {'id': 'ana-1', 'ad': 'Su Ana Sayac', 'tip': 'su'},
          ],
          'meta': {'total': 1},
        },
      '/sayaclar/bolum' => {
          'items': [
            {
              'id': 'b-1',
              'unit_id': 'u-1',
              'unit_no': 'A-3',
              'ilk_okuma': 140.0,
            },
          ],
          'meta': {'total': 1},
        },
      '/gelir-gider-tanimlari' => {
          'items': [
            {'id': 'kalem-1', 'ad': 'Su'},
          ],
          'meta': {'total': 1},
        },
      '/borclandirma/sayac' => {'atlanan': 0, 'olusan': 1},
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

Future<_Tel> _sur(WidgetTester tester, Widget ekran) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': 'yonetici', 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  // ========================= 4.2 PERSONEL EKLEME ========================= #

  testWidgets('PERSONEL EKLEME govdesinde E-POSTA VAR (422 kusuru)',
      (tester) async {
    final tel = await _sur(tester, const StaffScreen());
    // Bos listede cagri dugmesi ekranin ORTASINDA (P166 §10).
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Yeni Gorevli');
    await tester.enterText(find.byType(TextFormField).at(1), '05321112203');
    await tester.enterText(
        find.byKey(const Key('personel-eposta')), 'gorevli@ornek.com');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere(
        (i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde['email'], 'gorevli@ornek.com');
    expect(post.govde['telefon'], '+905321112203');
    expect(post.govde['role'], isNotNull);
  });

  testWidgets('E-POSTA BOSSA ISTEK ATILMAZ (sunucudan 422 beklenmez)',
      (tester) async {
    final tel = await _sur(tester, const StaffScreen());
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Yeni Gorevli');
    await tester.enterText(find.byType(TextFormField).at(1), '05321112203');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(
      tel.istekler.any((i) => i.yol == '/users' && i.metot == 'POST'),
      isFalse,
    );
  });

  // =========================== 4.5 SAYAC OKUMA =========================== #

  testWidgets('SAYAC: ana sayac secilince DAIRE SAYACLARI ve ONCEKI OKUMA',
      (tester) async {
    await _sur(tester, const SayacOkumaScreen());
    await tester.tap(find.byKey(const Key('sayac-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su Ana Sayac').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sayac-bolum-b-1')), findsOneWidget);
    // ONCEKI OKUMA GORUNUR: sahada en sik yapilan hata, degeri
    // oncekinin ALTINA yazmak.
    expect(find.textContaining('140'), findsOneWidget);
  });

  testWidgets('SAYAC: GERI SAYAN okuma ISTEK ATMADAN reddedilir',
      (tester) async {
    // Sunucuya gonderip 422 beklemek, sahada duran kisiyi bir
    // gidis-donus daha bekletirdi.
    final tel = await _sur(tester, const SayacOkumaScreen());
    await tester.tap(find.byKey(const Key('sayac-kalem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sayac-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su Ana Sayac').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('sayac-ana-tuketim')), '100');
    await tester.enterText(find.byKey(const Key('sayac-birim')), '35,50');
    await tester.enterText(find.byKey(const Key('sayac-deger-b-1')), '130');
    await tester.tap(find.byKey(const Key('sayac-gonder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sayac-hata')), findsOneWidget);
    expect(tel.istekler.any((i) => i.yol == '/borclandirma/sayac'), isFalse);
  });

  testWidgets('SAYAC: gecerli okumalar WEB ILE AYNI UCA gider', (tester) async {
    // Ikinci bir uc yazmak, dagitim kuralinin iki yerde ayrisma riski
    // demekti.
    final tel = await _sur(tester, const SayacOkumaScreen());
    await tester.tap(find.byKey(const Key('sayac-kalem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sayac-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Su Ana Sayac').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('sayac-ana-tuketim')), '100');
    await tester.enterText(find.byKey(const Key('sayac-birim')), '35,50');
    await tester.enterText(find.byKey(const Key('sayac-deger-b-1')), '150');
    await tester.tap(find.byKey(const Key('sayac-gonder')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/borclandirma/sayac');
    expect(post.govde['ana_sayac_id'], 'ana-1');
    expect(post.govde['gelir_gider_tanim_id'], 'kalem-1');
    expect(post.govde['ana_tuketim'], 100);
    expect(post.govde['birim_fiyat_kurus'], 3550);
    expect((post.govde['bolum_tuketimleri'] as Map)['b-1'], 150);
  });
}
