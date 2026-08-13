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

/// (P154 / Asama 3) ROL SECIMLI KAYIT — mobil ekran.
///
/// Olculen uc sey:
///   1. Brief'in DORT rolu listeleniyor (ve web'e ait `denetci` YOK),
///   2. Daire alani YALNIZ sakinde cikiyor (yoneticiden daire istenmez),
///   3. Kod dogrulanınca jeton denetleyiciye gecıyor — router'in parola
///      ekranina goturmesi buna bagli.

/// Cagrilari kaydeden sahte API. `AuthApi`yi Dio olmadan surmek icin
/// alt sinif: arayuzu genisletmek yerine yalniz iki metot ezildi.
class _SahteAuthApi extends AuthApi {
  _SahteAuthApi() : super(Dio());

  final baslaCagrilari = <Map<String, String?>>[];
  String? donenJeton;

  @override
  Future<({String tesisAd, String telefonMaskeli})> rolKayitBasla({
    required String rol,
    required String tesisKodu,
    required String telefon,
    String? daireNo,
    String? blok,
  }) async {
    baslaCagrilari.add({
      'rol': rol,
      'tesis_kodu': tesisKodu,
      'telefon': telefon,
      'daire_no': daireNo,
    });
    return (tesisAd: 'Oltu Sitesi', telefonMaskeli: '+9053***203');
  }

  @override
  Future<String> rolKayitDogrula({
    required String telefon,
    required String kod,
  }) async {
    return donenJeton ?? 'kurulum-jetonu';
  }
}

/// (P154 duzeltme turu) Sosyal yolu suren sahte depo.
///
/// `akis` VARSAYILAN OLARAK "eslesme gerekli" doner: kayit akisinda
/// beklenen sonuc budur (kimlik henuz hicbir hesaba bagli degil).
class _SahteOauthDepo implements OauthRepository {
  _SahteOauthDepo({this.saglayiciListesi = const ['google', 'apple']});

  final List<String> saglayiciListesi;
  final baglanBaslaCagrilari = <Map<String, String>>[];
  final baglanDogrulaCagrilari = <Map<String, String>>[];
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
      // (P155r2 §2) Saglayicinin bildirdigi ad — form bunu on-doldurur.
      ad: 'Ayse Saglayici',
    );
  }

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async {
    baglanBaslaCagrilari.add({'tesis_kodu': tesisKodu, 'telefon': telefon});
    return (tesisAd: 'Oltu Sitesi', telefonMaskeli: '+9053***203');
  }

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {
    baglanDogrulaCagrilari.add({'telefon': telefon, 'kod': kod});
  }
}

/// (P155r2) Sahte kayit deposu — `tesisOlustur` ve `setPassword` cagrilarini
/// kaydeder. `noSuchMethod` geri kalanini yutar; bu testler yalniz kayit
/// yolunu suruyor.
class _SahteKayitDepo implements AuthRepository {
  final tesisCagrilari = <Map<String, String?>>[];
  final parolaCagrilari = <String>[];

  @override
  Future<({String tesisAd, String tesisKodu})> tesisOlustur({
    required String tesisAd,
    required String ad,
    required String telefon,
    String? parola,
    String? baglamaJetonu,
  }) async {
    tesisCagrilari.add({
      'tesis_ad': tesisAd,
      'ad': ad,
      'telefon': telefon,
      'parola': parola,
      'baglama_jetonu': baglamaJetonu,
    });
    return (tesisAd: tesisAd, tesisKodu: 'OLTU-260715');
  }

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

/// Yeni sirada 3. adima (BILGILER) kadar goturur: rol -> yontem -> bilgiler.
Future<void> _bilgilereGit(
  WidgetTester tester, {
  String rol = 'yonetici',
  String ad = 'Ayse Yonetici',
  String telefon = '5321112203',
  String parola = 'CokGizliParola1',
}) async {
  await tester.tap(find.byKey(Key('kayit-rol-$rol')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('kayit-ad')), ad);
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
  testWidgets('brief’in DORT rolu listeleniyor, denetci YOK', (tester) async {
    await _sur(tester, _SahteAuthApi());

    for (final kimlik in ['yonetici', 'resident', 'security', 'tesis_gorevlisi']) {
      expect(
        find.byKey(Key('kayit-rol-$kimlik')),
        findsOneWidget,
        reason: '$kimlik rolu listede yok',
      );
    }
    // `denetci` WEB rolu; mobilde gosterilmesi brief'e aykiri olurdu.
    expect(find.byKey(const Key('kayit-rol-denetci')), findsNothing);
    expect(KayitRolu.values.length, 4);
  });

  testWidgets('daire alani YALNIZ sakinde cikar', (tester) async {
    // (P155r2) Daire artik 4. adimda (ROL OZEL) — sira degisti:
    // rol -> yontem -> bilgiler -> role ozel.
    final api = _SahteAuthApi();
    await _sur(tester, api, depo: _SahteKayitDepo());

    // Sakin: daire alani VAR.
    await _bilgilereGit(tester, rol: 'resident');
    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
  });

  testWidgets('yoneticiye daire SORULMAZ, TESIS ADI sorulur', (tester) async {
    await _sur(tester, _SahteAuthApi(), depo: _SahteKayitDepo());
    await _bilgilereGit(tester);

    expect(find.byIcon(Icons.meeting_room_outlined), findsNothing);
    expect(find.byKey(const Key('kayit-tesis-ad')), findsOneWidget);
    // Sartname §3: "Zaten bir sitem var" bagi tesis adi alaninin ALTINDA.
    expect(find.byKey(const Key('kayit-zaten-sitem-var')), findsOneWidget);
  });

  testWidgets('eslesme yolunda kod dogrulaninca PAROLA OTOMATIK gonderilir',
      (tester) async {
    // (P155r2) PAROLA IKI KEZ SORULMAZ: kullanici 3. adimda yazdi.
    // Jeton gelince ekran `/set-password`e GITMEZ, parolayi kendisi
    // gonderir. Olculen sey tam olarak bu.
    final api = _SahteAuthApi()..donenJeton = 'jeton-42';
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, depo: depo);

    await _bilgilereGit(tester, rol: 'resident');

    // BILGILER adimi AG CAGIRMAZ: cagriyi 4. adim (tesis kodu) baslatir.
    expect(api.baslaCagrilari, isEmpty);

    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // Telefon E.164'e NORMALLESTIRILEREK gitti (giris ekraniyla ayni kural).
    expect(api.baslaCagrilari.single['telefon'], '+905321112203');
    expect(api.baslaCagrilari.single['rol'], 'resident');
    expect(api.baslaCagrilari.single['daire_no'], '12');

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Parola KULLANICIYA TEKRAR SORULMADAN gonderildi.
    expect(depo.parolaCagrilari, ['CokGizliParola1']);
    // Ve oturum acildi.
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
    // `setupToken` NULL: jeton alindi, parola gonderildi, jeton temizlendi.
    // DOLU KALSAYDI router kullaniciyi `/set-password` ekranina goturur ve
    // az once yazdigi parolayi bir kez daha isterdi — bu testin asil
    // olctugu sey o ekranin GORUNMEMESI.
    expect(kap.read(authControllerProvider).setupToken, isNull);
  });

  // ============== (P155r2 / §3) YONETICI SELF-SIGNUP ================= //

  testWidgets('yonetici TESIS ACAR ve kod ekranda KOPYALANABILIR gorunur',
      (tester) async {
    final api = _SahteAuthApi();
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, depo: depo);

    await _bilgilereGit(tester);
    await tester.enterText(
        find.byKey(const Key('kayit-tesis-ad')), 'Oltu Sitesi');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // Tesis acma ucu ad + telefon + parolayla cagrildi; SMS/eslesme YOK.
    expect(depo.tesisCagrilari.single, {
      'tesis_ad': 'Oltu Sitesi',
      'ad': 'Ayse Yonetici',
      'telefon': '+905321112203',
      'parola': 'CokGizliParola1',
      'baglama_jetonu': null,
    });
    expect(api.baslaCagrilari, isEmpty, reason: 'eslesme ucu cagrilmamali');

    // Oturum ACILDI ve KOD GOSTERILIYOR (sartname §4: yonetici kodu elle
    // iletecek, o yuzden ana ekrana atlanmaz).
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
    expect(find.byKey(const Key('kayit-uretilen-kod')), findsOneWidget);
    expect(find.text('OLTU-260715'), findsOneWidget);
    expect(find.byKey(const Key('kayit-kod-kopyala')), findsOneWidget);
  });

  testWidgets('"Zaten bir sitem var" TESIS KODU alanina gecirir',
      (tester) async {
    // KATILMA TESIS ACMA DEGIL: KISITLAR geregi ikinci yonetici de
    // onceden EKLENMIS olmali, yani eslesme yoluna duser.
    final api = _SahteAuthApi();
    final depo = _SahteKayitDepo();
    await _sur(tester, api, depo: depo);

    await _bilgilereGit(tester);
    expect(find.byKey(const Key('kayit-tesis-ad')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kayit-zaten-sitem-var')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-tesis-ad')), findsNothing);
    expect(find.byKey(const Key('kayit-tesis-kodu')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // Tesis ACILMADI; eslesme ucu `rol=yonetici` ile cagrildi.
    expect(depo.tesisCagrilari, isEmpty);
    expect(api.baslaCagrilari.single['rol'], 'yonetici');
    expect(api.baslaCagrilari.single['tesis_kodu'], 'OLTU-260715');
  });

  // ================= (P154 duzeltme turu) YONTEM ADIMI ================= //

  testWidgets('yontem adimi brief’in DORT secenegini sunar', (tester) async {
    final oauth = _SahteOauthDepo(
      saglayiciListesi: const ['google', 'microsoft', 'apple'],
    );
    await _sur(tester, _SahteAuthApi(), oauth: oauth);

    // (P155r2) Yontem adimi ROL'DEN HEMEN SONRA gelir — sartname §2.
    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-yontem-parola')), findsOneWidget);
    for (final s in ['google', 'microsoft', 'apple']) {
      expect(find.byKey(Key('kayit-yontem-$s')), findsOneWidget,
          reason: '$s secenegi yontem adiminda yok');
    }
  });

  testWidgets('saglayici YAPILANDIRILMAMISSA yalniz parola cikar',
      (tester) async {
    // Bos liste = sosyal giris kapali. Cizilmeyen bir dugme, kullaniciyi
    // KESIN BASARISIZ bir yola sokmaktan iyidir (`SosyalGirisDugmeleri`
    // ile ayni kural).
    final oauth = _SahteOauthDepo(saglayiciListesi: const []);
    await _sur(tester, _SahteAuthApi(), oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-yontem-parola')), findsOneWidget);
    expect(find.byKey(const Key('kayit-yontem-google')), findsNothing);
  });

  testWidgets('SOSYAL yol: ad ON-DOLDURULUR, kayit ucu cagrilmaz',
      (tester) async {
    final api = _SahteAuthApi();
    final oauth = _SahteOauthDepo();
    final depo = _SahteKayitDepo();
    final kap = await _sur(tester, api, oauth: oauth, depo: depo);

    // Sakin + sosyal: rol -> Google -> bilgiler -> tesis kodu -> kod.
    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();

    expect(oauth.akisSaglayicisi, 'google');

    // SARTNAME §2: saglayicidan gelen ad soyad FORMA OTOMATIK DOLAR.
    final adAlani = tester.widget<TextFormField>(
      find.byKey(const Key('kayit-ad')),
    );
    expect(adAlani.controller?.text, 'Ayse Saglayici');
    // TELEFON BOS GELIR (hicbir saglayici vermiyor) — kullanici doldurur.
    final telAlani = tester.widget<TextFormField>(
      find.byKey(const Key('kayit-telefon')),
    );
    expect(telAlani.controller?.text, isEmpty);
    // SOSYAL YOLDA PAROLA ALANI YOK: kimlik saglayicidadir.
    expect(find.byKey(const Key('kayit-parola')), findsNothing);

    await tester.enterText(find.byKey(const Key('kayit-telefon')), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('kayit-tesis-kodu')), 'OLTU-260715');
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // KAYIT UCU HIC CAGRILMADI: sosyal yol kendi SMS'ini gonderir; ikisi
    // birden calissaydi kullaniciya iki kod giderdi.
    expect(api.baslaCagrilari, isEmpty);
    expect(oauth.baglanBaslaCagrilari.single, {
      'tesis_kodu': 'OLTU-260715',
      'telefon': '+905321112203',
    });

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(oauth.baglanDogrulaCagrilari.single, {
      'telefon': '+905321112203',
      'kod': '424242',
    });
    // Sosyal yolda PAROLA EKRANI YOK: oturum dogrudan acilir.
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
    expect(kap.read(authControllerProvider).setupToken, isNull);
  });

  testWidgets('SOSYAL + yonetici: tesis sosyal jetonla ACILIR', (tester) async {
    final oauth = _SahteOauthDepo();
    final depo = _SahteKayitDepo();
    await _sur(tester, _SahteAuthApi(), oauth: oauth, depo: depo);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kayit-telefon')), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('kayit-tesis-ad')), 'Oltu Sitesi');
    await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
    await tester.pumpAndSettle();

    // PAROLA YOK, baglama jetonu VAR — sunucu ikisini birden kabul etmez.
    expect(depo.tesisCagrilari.single['parola'], isNull);
    expect(depo.tesisCagrilari.single['baglama_jetonu'], 'baglama-1');
    expect(depo.tesisCagrilari.single['ad'], 'Ayse Saglayici');
  });
}
