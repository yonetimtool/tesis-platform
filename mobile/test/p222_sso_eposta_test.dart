/// (P222 §2) SSO KAYDINDA E-POSTA SAGLAYICIDAN GELIR — SORULMAZ.
///
/// ===========================================================================
/// OLCULEN DURUM
/// ===========================================================================
/// Sunucu e-postayi ZATEN biliyordu: `POST /auth/oauth/sonuc` yanitinda
/// `eposta` alani var ve `OauthSonuc.fromJson` onu COZUYOR. Kayilan yer
/// DENETLEYICIYDI: `AuthState`te `oauthAd` vardi ama `oauthEposta` YOKTU,
/// yani cozulen adres okunduktan hemen sonra atiliyordu ve ekran
/// kullaniciya "hangi hesapla kaydoluyorsun" sorusunu yanitlayamiyordu.
///
/// ===========================================================================
/// NEDEN GOSTERILIYOR, SORULMUYOR
/// ===========================================================================
/// Sunucu adresi HER SSO YOLUNDA imzali `baglama_jetonu`nun ICINDEN okur
/// (`kayit.tesis-olustur`, `oauth.rol-tamamla`); istemcinin yolladigi bir
/// deger HICBIR YERDE kullanilmaz. Duzenlenebilir bir alan, yazilanin
/// SESSIZCE yok sayilmasi demekti. Ayrica elle yazilan adres
/// DOGRULANMAMIS olurdu ve dogrulanmamis adresle allowlist eslesmesi
/// hesap ele gecirmedir (P180 dersi).
///
/// Taklit HTTP ADAPTER'INDA (P200 dersi): govdeyi cozen katman da testin
/// icinden geciyor. Depoyu ya da denetleyiciyi taklit etseydik, tam da
/// kirik olan halkayi olcmemis olurduk.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/oauth_tarayici.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/kayit_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.sonuc);

  final Map<String, dynamic> sonuc;
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
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final govde = switch (options.path) {
      '/auth/oauth/saglayicilar' => {
          'saglayicilar': ['google', 'microsoft', 'apple'],
        },
      '/auth/oauth/baslat/google' => {'adres': 'https://oauth.test/git'},
      '/auth/oauth/baslat/apple' => {'adres': 'https://oauth.test/git'},
      '/auth/oauth/baslat/microsoft' => {'adres': 'https://oauth.test/git'},
      '/auth/oauth/sonuc' => sonuc,
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

class _SahteTarayici implements OauthTarayici {
  @override
  Future<String?> akisiCalistir(String adres) async => 'sonuc-1';
}

Map<String, dynamic> _baglama({
  String? eposta,
  bool relay = false,
  String saglayici = 'google',
}) =>
    {
      'durum': 'baglama_gerekli',
      'saglayici': saglayici,
      if (eposta != null) 'eposta': eposta,
      'relay': relay,
      'ad': 'Ayse Yilmaz',
      'baglama_jetonu': 'baglama-1',
    };

Future<ProviderContainer> _sur(
    WidgetTester tester, Map<String, dynamic> sonuc, String saglayici) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = _Tel(sonuc);
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
    oauthTarayiciProvider.overrideWithValue(_SahteTarayici()),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const KayitScreen()),
    ),
  );
  await tester.pumpAndSettle();

  // ROL -> YONTEM -> saglayici. Gorunmeyene dokunmak sessizce hicbir sey
  // yapmaz; her adimda kaydiriyoruz.
  //
  // ROL `resident`: MOBILDE YONETICI KAYDI YOK (`KayitRolu` = sakin /
  // guvenlik / tesis_gorevlisi). Yonetici self-signup yalniz web'de.
  await _dokun(tester, const Key('kayit-rol-resident'));
  await _dokun(tester, Key('kayit-yontem-$saglayici'));
  return kap;
}

/// `scrollUntilVisible` KULLANILMIYOR: oge ZATEN gorunurken bile
/// kaydirmaya calisip "Bad state: No element" ile duşuyordu (ilk yazimda
/// alti testin altisi bu yuzden kirmiziydi). `ensureVisible` gerekliyse
/// kaydirir, gerekmiyorsa dokunmaz.
Future<void> _dokun(WidgetTester tester, Key anahtar) async {
  final f = find.byKey(anahtar);
  expect(f, findsOneWidget, reason: 'dokunulacak oge YOK: $anahtar');
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GOOGLE: saglayicinin adresi EKRANDA gorunur', (tester) async {
    await _sur(tester, _baglama(eposta: 'ayse@ornek.com'), 'google');
    expect(find.text('ayse@ornek.com'), findsOneWidget);
  });

  testWidgets('MICROSOFT: ayni sekilde dolar', (tester) async {
    await _sur(
      tester,
      _baglama(eposta: 'ayse@firma.com', saglayici: 'microsoft'),
      'microsoft',
    );
    expect(find.text('ayse@firma.com'), findsOneWidget);
  });

  testWidgets('APPLE PRIVATE RELAY: dolar VE posta gidemeyecegi soylenir',
      (tester) async {
    // P180 karari: relay adresi DOGRULANMIS sayilir (Apple'in kontrolunde)
    // ve otomatik dolar. Ama o adrese posta GONDERILEMEZ; kullanici bunu
    // kaydolmadan ONCE bilmeli.
    await _sur(
      tester,
      _baglama(
        eposta: 'abc123@privaterelay.appleid.com',
        relay: true,
        saglayici: 'apple',
      ),
      'apple',
    );
    expect(find.text('abc123@privaterelay.appleid.com'), findsOneWidget);
    expect(find.byKey(const Key('kayit-sosyal-eposta')), findsOneWidget);
  });

  testWidgets('APPLE E-POSTA VERMEZSE sebep SOYLENIR (sessiz bos alan yok)',
      (tester) async {
    // Apple e-postayi YALNIZ ilk yetkilendirmede verir. Kullanici kaydi
    // yarida birakip tekrar denerse adres GELMEZ ve sunucu bu yolu
    // `eposta_gerekli` (422) ile reddeder. Kullaniciyi sebepsiz bir
    // hataya surmek yerine durum ONCEDEN soyleniyor.
    await _sur(tester, _baglama(saglayici: 'apple'), 'apple');
    expect(find.byKey(const Key('kayit-sosyal-eposta-yok')), findsOneWidget);
    expect(find.byKey(const Key('kayit-sosyal-eposta')), findsNothing);
  });

  testWidgets('E-POSTA SORULMUYOR: SSO yolunda giris alani YOK',
      (tester) async {
    // Duzenlenebilir bir alan, yazilanin sunucuda yok sayilmasi demekti.
    await _sur(tester, _baglama(eposta: 'ayse@ornek.com'), 'google');
    expect(find.byKey(const Key('kayit-eposta')), findsNothing);
  });

  testWidgets('IPTAL EDINCE adres TEMIZLENIR (sonraki denemeye sizmaz)',
      (tester) async {
    final kap = await _sur(tester, _baglama(eposta: 'ayse@ornek.com'), 'google');
    expect(kap.read(authControllerProvider).oauthEposta, 'ayse@ornek.com');
    kap.read(authControllerProvider.notifier).oauthIptal();
    expect(kap.read(authControllerProvider).oauthEposta, isNull);
  });
}
