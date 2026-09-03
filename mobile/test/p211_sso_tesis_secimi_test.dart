/// (P211 §1) SSO SONRASI TESIS SECIMI — Tesis ID SORULMAZ.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Cok tesisli bir yonetici "Google ile devam" dediginde sunucu
/// `baglama_gerekli` donuyordu (e-posta eslesmesi BIRDEN COK oldugu icin)
/// ve ekran TESIS ID soran formu aciyordu — P205'te parola yolunda
/// kaldirdigimiz sartin ta kendisi.
///
/// Taklit HTTP adapter'inda (P200 dersi): govdeyi kuran katman da testin
/// icinden geciyor. Olculen sey: hangi uca hangi govde gitti ve ekranda
/// hangi mod cizildi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/oauth_tarayici.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.sonuc);

  /// `/auth/oauth/sonuc` yaniti — akisin hangi dala gidecegini belirler.
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
      '/auth/oauth/sonuc' => sonuc,
      '/auth/oauth/tesis-sec' => {
          'durum': 'giris',
          'jetonlar': {
            'access_token': 'erisim',
            'refresh_token': 'yenileme',
            'token_type': 'bearer',
            'expires_in': 900,
          },
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

class _SahteTarayici implements OauthTarayici {
  String? gidilenAdres;

  @override
  Future<String?> akisiCalistir(String adres) async {
    gidilenAdres = adres;
    return 'sonuc-1';
  }
}

const _IKI_TESIS = {
  'durum': 'tesis_secimi',
  'saglayici': 'google',
  'eposta': 'yonetici@ornek.com',
  'secim_jetonu': 'secim-1',
  'tesisler': [
    {'tenant_id': 't-1', 'ad': 'Oltu Sitesi', 'slug': 'oltu-sitesi'},
    {'tenant_id': 't-2', 'ad': 'City Ambiance', 'slug': 'city-ambiance'},
  ],
};

const _BAGLAMA = {
  'durum': 'baglama_gerekli',
  'saglayici': 'google',
  'eposta': 'yeni@ornek.com',
  'baglama_jetonu': 'baglama-1',
};

Future<_Tel> _sur(WidgetTester tester, Map<String, dynamic> sonuc) async {
  final tel = _Tel(sonuc);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
    oauthTarayiciProvider.overrideWithValue(_SahteTarayici()),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

/// SSO dugmesi ekranin ALTINDA kaliyor; gorunmeyene dokunmak sessizce
/// hicbir sey yapmiyor ("warnIfMissed" uyarisi + bos ekran — ilk
/// kosumda tam olarak bu oldu).
Future<void> _googleTikla(WidgetTester tester) async {
  final dugme = find.byKey(const Key('sosyal-google'));
  await tester.scrollUntilVisible(dugme, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(dugme);
  await tester.pumpAndSettle();
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SSO DUGMELERI cizilir (saglayici listesi doluysa)',
      (tester) async {
    // Liste BOSSA hicbir sey cizilmez ve bu DOGRU davranis: yapilandirilmamis
    // bir saglayiciyi dugme olarak gostermek, kullaniciyi kesin basarisiz
    // bir yola sokmakti. Burada olculen sey: liste DOLUYKEN cizildigi.
    await _sur(tester, _IKI_TESIS);
    expect(find.byKey(const Key('sosyal-google')), findsOneWidget);
    expect(find.byKey(const Key('sosyal-microsoft')), findsOneWidget);
    expect(find.byKey(const Key('sosyal-apple')), findsOneWidget);
  });

  testWidgets('COK TESISLI YONETICI: TESIS ID DEGIL, SECIM cizilir',
      (tester) async {
    await _sur(tester, _IKI_TESIS);
    await _googleTikla(tester);

    expect(find.byKey(const Key('sso-tesis-secimi')), findsOneWidget);
    expect(find.byKey(const Key('sso-tesis-oltu-sitesi')), findsOneWidget);
    expect(find.byKey(const Key('sso-tesis-city-ambiance')), findsOneWidget);
    // TESIS ID ALANI YOK: eski cikmaz kapandi.
    expect(find.byKey(const Key('sosyal-tesis-kodu')), findsNothing);
    expect(find.textContaining('Tesis ID'), findsNothing);
  });

  testWidgets('SECILEN TESIS govdeye gider ve OTURUM acilir', (tester) async {
    final tel = await _sur(tester, _IKI_TESIS);
    await _googleTikla(tester);
    await tester.tap(find.byKey(const Key('sso-tesis-city-ambiance')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere(
        (i) => i.yol == '/auth/oauth/tesis-sec');
    expect(post.govde['secim_jetonu'], 'secim-1');
    expect(post.govde['tenant_id'], 't-2');
  });

  testWidgets('KIMLIGI BAGLI OLMAYAN YENI kullanicida BAGLAMA formu DURUYOR',
      (tester) async {
    // Secim dali, baglama akisini KALDIRMADI: hesabi olmayan biri hâlâ
    // Tesis ID ile baglanir (kayit/davet yolu).
    await _sur(tester, _BAGLAMA);
    await _googleTikla(tester);
    expect(find.byKey(const Key('sso-tesis-secimi')), findsNothing);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
