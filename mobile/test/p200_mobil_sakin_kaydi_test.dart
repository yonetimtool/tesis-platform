/// (P200 §2) MOBIL SAKIN KAYDI — AKISIN TAMAMI, GIDEN GOVDEYLE.
///
/// ===========================================================================
/// VAR OLAN TESTTEN FARKI: DIKIS NEREDE TAKLIT EDILIYOR
/// ===========================================================================
/// `kayit_rol_secimi_test.dart` bu akisi zaten suruyor — ama taklidi
/// `AuthApi` / `OauthRepository` DUZEYINDE kuruyor. Yani istegin GOVDESINI
/// kuran katman (`auth_api.dart` icindeki `data: {...}`) testte HIC
/// calismiyor. P198'de kirilan sey tam olarak boyle bir dikisti: parcalar
/// olculuyordu, aralarindaki gecis olculmuyordu.
///
/// Burada taklit EN ALTA, HTTP adapter'ina konur. Ekran -> denetleyici ->
/// depo -> api -> **tel uzerindeki govde** zincirinin tamami GERCEKTIR.
/// Olculen sey: hangi uca, hangi JSON gitti.
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
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/kayit_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

/// Tel uzerindeki istegi KAYDEDEN, yola gore yanit doner sahte adapter.
class _TelAdapteri implements HttpClientAdapter {
  _TelAdapteri(this.yanitlar);

  /// yol (path) -> govde. Eslesmeyen yol testi ACIKCA dusurur; sessiz
  /// bir 404, "uc hic cagrilmadi" kusurunu gizlerdi.
  final Map<String, Map<String, dynamic>> yanitlar;

  final istekler = <({String yol, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final yol = options.path;
    final ham = options.data;
    istekler.add((
      yol: yol,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final govde = yanitlar[yol];
    if (govde == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'not_found', 'message': 'taklit yok: $yol'}
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
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

  /// Verilen uca giden TEK istegin govdesi.
  Map<String, dynamic> govde(String yol) {
    final eslesen = istekler.where((i) => i.yol == yol).toList();
    expect(eslesen, hasLength(1), reason: '$yol tam bir kez cagrilmali');
    return eslesen.single.govde;
  }

  List<String> get yollar => istekler.map((i) => i.yol).toList();
}

/// Tarayici donusunu taklit eder — gercek `flutter_web_auth_2` cagrilmaz.
class _SahteTarayici implements OauthTarayici {
  _SahteTarayici({this.sonucId = 'sonuc-1'});

  final String? sonucId;
  String? gidilenAdres;

  @override
  Future<String?> akisiCalistir(String adres) async {
    gidilenAdres = adres;
    return sonucId;
  }
}

const _JETONLAR = {
  'access_token': 'erisim-jetonu',
  'refresh_token': 'yenileme-jetonu',
  'token_type': 'bearer',
};

/// SSO yolu icin taklit yanitlari. `rolTamamlaYaniti` degistirilerek
/// `giris` / `otp_gerekli` / `onay_bekliyor` dallari surulur.
Map<String, Map<String, dynamic>> _ssoYanitlari({
  Map<String, dynamic>? rolTamamla,
  Map<String, dynamic>? rolTamamlaDogrula,
}) =>
    {
      '/auth/oauth/saglayicilar': {
        'saglayicilar': ['google', 'microsoft', 'apple'],
      },
      '/auth/oauth/baslat/google': {'adres': 'https://oauth.test/git'},
      '/auth/oauth/sonuc': {
        'durum': 'baglama_gerekli',
        'saglayici': 'google',
        'baglama_jetonu': 'baglama-1',
        'ad': 'Ayse Sakin',
      },
      '/auth/oauth/rol-tamamla':
          rolTamamla ?? {'durum': 'giris', ..._JETONLAR},
      '/auth/oauth/rol-tamamla-dogrula':
          rolTamamlaDogrula ?? {'durum': 'giris', ..._JETONLAR},
    };

Future<({ProviderContainer kap, _TelAdapteri tel, _SahteTarayici tarayici})>
    _sur(
  WidgetTester tester,
  Map<String, Map<String, dynamic>> yanitlar, {
  String? sonucId = 'sonuc-1',
}) async {
  final tel = _TelAdapteri(yanitlar);
  final tarayici = _SahteTarayici(sonucId: sonucId);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;

  final kap = ProviderContainer(
    overrides: [
      // TEK TAKLIT NOKTASI: tasima katmani. Ustundeki her sey GERCEK.
      dioProvider.overrideWithValue(dio),
      tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
      oauthTarayiciProvider.overrideWithValue(tarayici),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const KayitScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (kap: kap, tel: tel, tarayici: tarayici);
}

/// Rol sec -> yontem sec -> (SSO ise) tesis kodu adimi.
Future<void> _rolVeSaglayici(
  WidgetTester tester, {
  required String rol,
  String saglayici = 'google',
}) async {
  await tester.tap(find.byKey(Key('kayit-rol-$rol')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('kayit-yontem-$saglayici')));
  await tester.pumpAndSettle();
}

Future<void> _tesisKodu(WidgetTester tester, String kod) async {
  await tester.enterText(find.byKey(const Key('kayit-tesis-kodu')), kod);
  await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('SSO AKISI: rol -> Tesis ID -> rol-tamamla govdesi -> oturum',
      (tester) async {
    final s = await _sur(tester, _ssoYanitlari());

    await _rolVeSaglayici(tester, rol: 'resident');
    // Tarayici GERCEK adresle acildi (uc -> adres -> tarayici zinciri).
    expect(s.tarayici.gidilenAdres, 'https://oauth.test/git');
    // SSO yolu BILGILER adimini atlar.
    expect(find.byKey(const Key('kayit-ad')), findsNothing);
    expect(find.byKey(const Key('kayit-tesis-kodu')), findsOneWidget);

    await _tesisKodu(tester, 'OLTU-260715');

    // ============ OLCULEN SEY: TEL UZERINDEKI GOVDE ============
    expect(s.tel.govde('/auth/oauth/rol-tamamla'), {
      'baglama_jetonu': 'baglama-1',
      'tesis_kodu': 'OLTU-260715',
      'rol': 'resident',
    });
    // E-posta/SMS uclari HIC cagrilmadi.
    expect(s.tel.yollar, isNot(contains('/auth/kayit/rol-eposta-basla')));
    expect(s.kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('SSO + otp_gerekli: kod adimi -> dogrulama govdesi -> oturum',
      (tester) async {
    final s = await _sur(
      tester,
      _ssoYanitlari(
        rolTamamla: {'durum': 'otp_gerekli', 'tesis_ad': 'Oltu Sitesi'},
      ),
    );

    await _rolVeSaglayici(tester, rol: 'security');
    await _tesisKodu(tester, 'OLTU-260715');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-kod-gonder')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // IKINCI ADIM AYNI ROLU ve AYNI JETONU tasimali; kod EKLENIR.
    expect(s.tel.govde('/auth/oauth/rol-tamamla-dogrula'), {
      'baglama_jetonu': 'baglama-1',
      'tesis_kodu': 'OLTU-260715',
      'rol': 'security',
      'kod': '424242',
    });
    expect(s.kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('PAROLA AKISI: bilgiler -> Tesis ID -> iki ucun govdesi',
      (tester) async {
    final s = await _sur(tester, {
      '/auth/oauth/saglayicilar': {'saglayicilar': <String>[]},
      '/auth/kayit/rol-eposta-basla': {'tesis_ad': 'Oltu Sitesi'},
      '/auth/kayit/rol-eposta-dogrula': {
        'durum': 'hazir',
        'setup_token': 'kurulum-jetonu',
      },
      '/auth/set-password': _JETONLAR,
    });

    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kayit-ad')), 'Ayse Sakin');
    await tester.enterText(
        find.byKey(const Key('kayit-eposta')), 'ayse@ornek.com');
    await tester.enterText(
        find.byKey(const Key('kayit-telefon')), '5321112203');
    await tester.enterText(
        find.byKey(const Key('kayit-parola')), 'CokGizliParola1!');
    await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
    await tester.pumpAndSettle();

    // BILGILER adimi AG CAGIRMAZ.
    expect(s.tel.yollar, isNot(contains('/auth/kayit/rol-eposta-basla')));

    await _tesisKodu(tester, 'OLTU-260715');
    await tester.pumpAndSettle();

    final basla = s.tel.govde('/auth/kayit/rol-eposta-basla');
    expect(basla['rol'], 'resident');
    expect(basla['tesis_kodu'], 'OLTU-260715');
    expect(basla['eposta'], 'ayse@ornek.com');
    expect(basla['ad'], 'Ayse Sakin');
    // Telefon ILETISIM bilgisi; girildiyse gonderilir (SMS icin DEGIL).
    expect(basla['telefon'], isNotNull);

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(s.tel.govde('/auth/kayit/rol-eposta-dogrula'), {
      'tesis_kodu': 'OLTU-260715',
      'eposta': 'ayse@ornek.com',
      'kod': '424242',
    });
    expect(s.kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('ROL GOVDEDE SUNUCU KIMLIGIYLE gider (ekran etiketi DEGIL)',
      (tester) async {
    // `tesis_gorevlisi` DB enum'uyla birebir olmali; kisa "gorevli"
    // yazilsaydi sunucu rolu tanimaz, `onay_bekliyor` doner ve kullanici
    // onay kuyrugunda kalirdi (P184'te bir kez yasandi).
    final s = await _sur(tester, _ssoYanitlari());
    await _rolVeSaglayici(tester, rol: 'tesis_gorevlisi');
    await _tesisKodu(tester, 'OLTU-260715');

    expect(s.tel.govde('/auth/oauth/rol-tamamla')['rol'], 'tesis_gorevlisi');
  });

  testWidgets('onay_bekliyor: hesap ACILMAZ, kart gorunur', (tester) async {
    final s = await _sur(
      tester,
      _ssoYanitlari(rolTamamla: {'durum': 'onay_bekliyor'}),
    );
    await _rolVeSaglayici(tester, rol: 'resident');
    await _tesisKodu(tester, 'YANLIS-KOD');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsOneWidget);
    expect(s.kap.read(authControllerProvider).status,
        isNot(AuthStatus.authenticated));
  });

  testWidgets('SUNUCU HATA DONERSE: mesaj gorunur, dugme KILITLI KALMAZ',
      (tester) async {
    // Bu testin BULDUGU kusur: hata dalinda `hataKimligi: e.code`
    // (String) enum'a cast ediliyordu ve `catch` blogunun ICINDE
    // TypeError atiyordu. Istisna disari sizip `_bekliyor` bayragini
    // acik birakiyor, kullanici SONSUZA KADAR DONEN bir dugme ve
    // HICBIR hata metni goruyordu. Akis surulmeden gorunmuyordu.
    final tel = _TelAdapteri({
      '/auth/oauth/saglayicilar': {
        'saglayicilar': ['google'],
      },
      '/auth/oauth/baslat/google': {'adres': 'https://oauth.test/git'},
      '/auth/oauth/sonuc': {
        'durum': 'baglama_gerekli',
        'saglayici': 'google',
        'baglama_jetonu': 'baglama-1',
      },
      // rol-tamamla TAKLIDI YOK -> adapter 404 + hata zarfi doner.
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    final kap = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
      oauthTarayiciProvider.overrideWithValue(_SahteTarayici()),
    ]);
    addTearDown(kap.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const KayitScreen()),
    ));
    await tester.pumpAndSettle();

    await _rolVeSaglayici(tester, rol: 'resident');
    await _tesisKodu(tester, 'OLTU-260715');
    await tester.pumpAndSettle();

    // 1) SUNUCUNUN mesaji ekranda.
    expect(find.text('taklit yok: /auth/oauth/rol-tamamla'), findsOneWidget);
    // 2) Ekran TESIS KODU adiminda kaldi ve dugme YENIDEN BASILABILIR
    //    (bekleme bayragi acik kalmadi).
    expect(find.byKey(const Key('kayit-tesis-kodu')), findsOneWidget);
    expect(find.byKey(const Key('kayit-rol-ozel-gonder')), findsOneWidget);
    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsNothing);
  });

  testWidgets('TARAYICI KAPATILDI: tesis kodu adimina GECILMEZ',
      (tester) async {
    // Vazgecme HATA DEGILDIR; ekran yontem adiminda kalmali. Gecseydi
    // kullanici baglama jetonu OLMADAN Tesis ID girer ve uc reddederdi.
    final s = await _sur(tester, _ssoYanitlari(), sonucId: null);
    await _rolVeSaglayici(tester, rol: 'resident');

    expect(find.byKey(const Key('kayit-tesis-kodu')), findsNothing);
    expect(s.tel.yollar, isNot(contains('/auth/oauth/rol-tamamla')));
  });
}
