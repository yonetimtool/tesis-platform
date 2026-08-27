import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/oauth_repository.dart';
import 'package:mobile/src/features/auth/domain/oauth_sonuc.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/kayit_screen.dart';

import 'helpers/l10n_test_app.dart';

/// (P184) TESIS ID ILE TAMAMLAMA — mobil ekran. SMS YOK, dogrulama e-posta.
///
/// Olculen sey:
///   1. UC rol listeleniyor (yonetici mobilde KAYDOLMAZ, denetci web'e ait),
///   2. E-posta ZORUNLU; telefon istege bagli,
///   3. Parola yolu e-posta OTP ucunu (`rol-eposta-*`) cagirir; `hazir`da
///      parola OTOMATIK gonderilir (set-password ekrani gorunmez),
///   4. `onay_bekliyor`da hesap ACILMAZ, kullaniciya soylenir,
///   5. SSO yolu `rol-tamamla` cagirir; `giris`te oturum acilir,
///      `otp_gerekli`de e-posta OTP adimina duser.

/// Cagrilari kaydeden sahte API. E-POSTA uclarini ezer (SMS uclari DEGIL).
class _SahteAuthApi extends AuthApi {
  _SahteAuthApi({this.dogrulaDurum = 'hazir'}) : super(Dio());

  final baslaCagrilari = <Map<String, String?>>[];
  final dogrulaCagrilari = <Map<String, String>>[];

  /// `rol-eposta-dogrula` ne dönsün: 'hazir' | 'onay_bekliyor'.
  final String dogrulaDurum;

  @override
  Future<String> rolEpostaBasla({
    required String rol,
    required String tesisKodu,
    required String eposta,
    String? ad,
    String? telefon,
  }) async {
    baslaCagrilari.add({
      'rol': rol,
      'tesis_kodu': tesisKodu,
      'eposta': eposta,
      'ad': ad,
      'telefon': telefon,
    });
    return 'Oltu Sitesi';
  }

  @override
  Future<({String durum, String? setupToken})> rolEpostaDogrula({
    required String tesisKodu,
    required String eposta,
    required String kod,
  }) async {
    dogrulaCagrilari.add({'tesis_kodu': tesisKodu, 'eposta': eposta, 'kod': kod});
    return dogrulaDurum == 'hazir'
        ? (durum: 'hazir', setupToken: 'kurulum-jetonu')
        : (durum: 'onay_bekliyor', setupToken: null);
  }
}

/// SSO yolunu suren sahte depo. `akis` "baglama gerekli" doner (kimlik henuz
/// bagli degil). `rolTamamla`/`rolTamamlaDogrula` durumu yapilandirilabilir.
class _SahteOauthDepo implements OauthRepository {
  _SahteOauthDepo({
    this.saglayiciListesi = const ['google', 'apple'],
    this.tamamlaDurum = 'giris',
  });

  final List<String> saglayiciListesi;

  /// `rol-tamamla` ne dönsün: 'giris' | 'otp_gerekli' | 'onay_bekliyor'.
  final String tamamlaDurum;

  final tamamlaCagrilari = <Map<String, String>>[];
  final dogrulaCagrilari = <Map<String, String>>[];
  String? akisSaglayicisi;

  @override
  Future<List<String>> saglayicilar() async => saglayiciListesi;

  @override
  Future<OauthSonuc?> akis(String saglayici) async {
    akisSaglayicisi = saglayici;
    return OauthSonuc(
      durum: 'baglama_gerekli',
      saglayici: saglayici,
      baglamaJetonu: 'baglama-1',
      ad: 'Ayse Saglayici',
    );
  }

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async =>
      (tesisAd: 'Oltu Sitesi', telefonMaskeli: '+9053***203');

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {}

  @override
  Future<({String durum, String? tesisAd})> rolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
  }) async {
    tamamlaCagrilari.add({'tesis_kodu': tesisKodu, 'rol': rol});
    return (
      durum: tamamlaDurum,
      tesisAd: tamamlaDurum == 'otp_gerekli' ? 'Oltu Sitesi' : null,
    );
  }

  @override
  Future<({String durum})> rolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    required String rol,
    required String kod,
  }) async {
    dogrulaCagrilari.add({'tesis_kodu': tesisKodu, 'rol': rol, 'kod': kod});
    return (durum: 'giris');
  }
}

/// Sahte kayit deposu — `setPassword` cagrilarini kaydeder.
class _SahteKayitDepo implements AuthRepository {
  final parolaCagrilari = <String>[];

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {
    parolaCagrilari.add(newPassword);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Parola yolunda BILGILER adimini doldurur: rol -> yontem -> bilgiler.
Future<void> _bilgilereGit(
  WidgetTester tester, {
  String rol = 'resident',
  String ad = 'Ayse Sakin',
  String eposta = 'ayse@ornek.com',
  String telefon = '5321112203',
  String parola = 'CokGizliParola1',
}) async {
  await tester.tap(find.byKey(Key('kayit-rol-$rol')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('kayit-ad')), ad);
  await tester.enterText(find.byKey(const Key('kayit-eposta')), eposta);
  await tester.enterText(find.byKey(const Key('kayit-telefon')), telefon);
  await tester.enterText(find.byKey(const Key('kayit-parola')), parola);
  await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _sur(
  WidgetTester tester,
  _SahteAuthApi api, {
  _SahteOauthDepo? oauth,
  _SahteKayitDepo? depo,
}) async {
  final kap = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(api),
      if (oauth != null) oauthRepositoryProvider.overrideWithValue(oauth),
      if (depo != null) authRepositoryProvider.overrideWithValue(depo),
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
  return kap;
}

void main() {
  testWidgets('UC rol listeleniyor; yonetici + denetci YOK', (tester) async {
    await _sur(tester, _SahteAuthApi());

    for (final kimlik in ['resident', 'security', 'tesis_gorevlisi']) {
      expect(find.byKey(Key('kayit-rol-$kimlik')), findsOneWidget,
          reason: '$kimlik rolu listede yok');
    }
    // Yonetici mobilde KAYDOLMAZ (web'den), denetci WEB rolu.
    expect(find.byKey(const Key('kayit-rol-yonetici')), findsNothing);
    expect(find.byKey(const Key('kayit-rol-denetci')), findsNothing);
    expect(KayitRolu.values.length, 3);
  });

  testWidgets('E-POSTA zorunlu: bos birakilirsa ilerlemez', (tester) async {
    final api = _SahteAuthApi();
    await _sur(tester, api);
    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kayit-ad')), 'Ayse');
    // E-posta BOS.
    await tester.enterText(find.byKey(const Key('kayit-parola')), 'Parola123!');
    await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
    await tester.pumpAndSettle();

    // Hala BILGILER adiminda — tesis kodu adimina gecmedi.
    expect(find.byKey(const Key('kayit-eposta')), findsOneWidget);
    expect(find.byKey(const Key('kayit-tesis-kodu')), findsNothing);
  });

  testWidgets('parola yolu: e-posta OTP dogru -> parola OTOMATIK, oturum',
      (tester) async {
    final api = _SahteAuthApi(dogrulaDurum: 'hazir');
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, depo: depo);

    await _bilgilereGit(tester, rol: 'resident');
    // BILGILER adimi AG CAGIRMAZ: cagriyi 4. adim (tesis kodu) baslatir.
    expect(api.baslaCagrilari, isEmpty);

    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // E-POSTA ucu rol + tesis + e-posta ile cagrildi (SMS/telefon-kod DEGIL).
    expect(api.baslaCagrilari.single['rol'], 'resident');
    expect(api.baslaCagrilari.single['eposta'], 'ayse@ornek.com');
    expect(api.baslaCagrilari.single['tesis_kodu'], 'OLTU-260715');

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Parola KULLANICIYA TEKRAR SORULMADAN gonderildi + oturum acildi.
    expect(depo.parolaCagrilari, ['CokGizliParola1']);
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
    expect(kap.read(authControllerProvider).setupToken, isNull);
  });

  testWidgets('parola yolu: onay_bekliyor -> hesap ACILMAZ, kart gorunur',
      (tester) async {
    final api = _SahteAuthApi(dogrulaDurum: 'onay_bekliyor');
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, depo: depo);

    await _bilgilereGit(tester, rol: 'resident');
    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'YANLIS-KOD');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pumpAndSettle();

    // ONAY BEKLIYOR karti gorunur; hesap ACILMADI; parola gonderilmedi.
    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsOneWidget);
    expect(depo.parolaCagrilari, isEmpty);
    expect(kap.read(authControllerProvider).status, isNot(AuthStatus.authenticated));
  });

  testWidgets('yontem adimi SSO + parola sunar (yonetici yok)', (tester) async {
    final oauth = _SahteOauthDepo(
      saglayiciListesi: const ['google', 'microsoft', 'apple'],
    );
    await _sur(tester, _SahteAuthApi(), oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-yontem-parola')), findsOneWidget);
    for (final s in ['google', 'microsoft', 'apple']) {
      expect(find.byKey(Key('kayit-yontem-$s')), findsOneWidget);
    }
  });

  testWidgets('SSO yolu: bilgiler ATLANIR, rol-tamamla giris -> oturum',
      (tester) async {
    final api = _SahteAuthApi();
    final oauth = _SahteOauthDepo(tamamlaDurum: 'giris');
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, oauth: oauth, depo: depo);

    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();

    // SSO yolu BILGILER adimini ATLAR — dogrudan tesis kodu.
    expect(oauth.akisSaglayicisi, 'google');
    expect(find.byKey(const Key('kayit-ad')), findsNothing);
    expect(find.byKey(const Key('kayit-tesis-kodu')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    // GIRIS'te router yonlendirir; testte router yok, buton spinner'i doner —
    // pumpAndSettle DEGIL pump (sonsuz animasyonu beklemez).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // E-POSTA/SMS ucu HIC cagrilmadi; rol-tamamla cagrildi ve oturum acildi.
    expect(api.baslaCagrilari, isEmpty);
    expect(oauth.tamamlaCagrilari.single, {
      'tesis_kodu': 'OLTU-260715',
      'rol': 'resident',
    });
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('SSO yolu: otp_gerekli -> e-posta OTP adimi -> oturum',
      (tester) async {
    final api = _SahteAuthApi();
    final oauth = _SahteOauthDepo(tamamlaDurum: 'otp_gerekli');
    final kap = await _sur(tester, api, oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-security')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // OTP adimina dustu (email_verified=false).
    expect(find.byKey(const Key('kayit-kod-gonder')), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(oauth.dogrulaCagrilari.single, {
      'tesis_kodu': 'OLTU-260715',
      'rol': 'security',
      'kod': '424242',
    });
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('SSO yolu: onay_bekliyor -> hesap ACILMAZ, kart gorunur',
      (tester) async {
    final oauth = _SahteOauthDepo(tamamlaDurum: 'onay_bekliyor');
    final kap = await _sur(tester, _SahteAuthApi(), oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-tesis_gorevlisi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsOneWidget);
    expect(kap.read(authControllerProvider).status, isNot(AuthStatus.authenticated));
  });
}
