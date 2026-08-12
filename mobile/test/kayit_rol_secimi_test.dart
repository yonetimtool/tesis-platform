import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
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

Future<ProviderContainer> _sur(
  WidgetTester tester,
  _SahteAuthApi api, {
  _SahteOauthDepo? oauth,
}) async {
  final kap = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(api),
      if (oauth != null) oauthRepositoryProvider.overrideWithValue(oauth),
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
    final api = _SahteAuthApi();
    await _sur(tester, api);

    // Yonetici: daire alani YOK.
    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.meeting_room_outlined), findsNothing);

    // Geri don, sakini sec: daire alani VAR.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
  });

  testWidgets('kod dogrulaninca jeton DENETLEYICIYE gecer', (tester) async {
    final api = _SahteAuthApi()..donenJeton = 'jeton-42';
    final kap = await _sur(tester, api);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'OLTU-260715',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-kimlik-gonder')));
    await tester.pumpAndSettle();

    // (P154 duzeltme turu) KIMLIK ADIMI ARTIK CAGRI YAPMIYOR: brief
    // yontemi telefondan SONRA soruyor ve SMS'i baslatan sey yontem
    // secimidir. Kimlik adimi cagirsaydi "Google" secen kullaniciya
    // gereksiz bir kayit SMS'i gitmis olurdu.
    expect(api.baslaCagrilari, isEmpty);

    await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
    await tester.pumpAndSettle();

    // Telefon E.164'e NORMALLESTIRILEREK gitti (giris ekraniyla ayni kural).
    expect(api.baslaCagrilari.single['telefon'], '+905321112203');
    expect(api.baslaCagrilari.single['rol'], 'yonetici');
    // Yoneticiden daire ISTENMEDI.
    expect(api.baslaCagrilari.single['daire_no'], isNull);

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    // `pumpAndSettle` DEGIL: basarili yolda `_bekliyor` BILEREK `true`
    // kaliyor (router ekrani degistirene kadar cift gonderimi engeller) ve
    // spinner sonsuz animasyon oldugu icin agac hic "oturmaz". Gercek
    // uygulamada bu bir sorun degil — orada router ekrani kaldiriyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Ekran KENDI navigasyonunu yapmaz; jetonu denetleyiciye birakir ve
    // router `setupToken` dolunca parola ekranina goturur.
    expect(kap.read(authControllerProvider).setupToken, 'jeton-42');
  });

  // ================= (P154 duzeltme turu) YONTEM ADIMI ================= //

  testWidgets('yontem adimi brief’in DORT secenegini sunar', (tester) async {
    final oauth = _SahteOauthDepo(
      saglayiciListesi: const ['google', 'microsoft', 'apple'],
    );
    await _sur(tester, _SahteAuthApi(), oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'OLTU-260715');
    await tester.enterText(find.byType(TextFormField).at(1), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-kimlik-gonder')));
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
    await tester.enterText(find.byType(TextFormField).at(0), 'OLTU-260715');
    await tester.enterText(find.byType(TextFormField).at(1), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-kimlik-gonder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kayit-yontem-parola')), findsOneWidget);
    expect(find.byKey(const Key('kayit-yontem-google')), findsNothing);
  });

  testWidgets('SOSYAL yol: kayit ucu cagrilmaz, eslesme ZATEN girilen '
      'tesis+telefon ile yapilir', (tester) async {
    final api = _SahteAuthApi();
    final oauth = _SahteOauthDepo();
    final kap = await _sur(tester, api, oauth: oauth);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'OLTU-260715');
    await tester.enterText(find.byType(TextFormField).at(1), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-kimlik-gonder')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kayit-yontem-google')));
    await tester.pumpAndSettle();

    expect(oauth.akisSaglayicisi, 'google');
    // KAYIT UCU HIC CAGRILMADI: sosyal yol kendi SMS'ini gonderir; ikisi
    // birden calissaydi kullaniciya iki kod giderdi.
    expect(api.baslaCagrilari, isEmpty);
    // Kullaniciya tesis kodu/telefon IKINCI KEZ SORULMADI — brief bu iki
    // alani yontemden ONCE istiyor ve elimizdeler.
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
}
