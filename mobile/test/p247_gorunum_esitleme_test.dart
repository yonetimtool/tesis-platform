/// (P247 §7) BUYUK MOD "8'DEN 4'E DUSMUYOR" — GERCEK UYGULAMA KOKUYLE.
///
/// OLCUM: cihaz-yerel yol (P230) CALISIYORDU — depo "buyuk" iken ve ayardan
/// secilince 4 karo ciziliyordu (bu dosyanin 3. senaryosu, duzeltmeden once
/// de yesil). Kirik olan IKINCI kaynakti: P243 §4 ayni ayari hesaba
/// (`app_user.ui_gorunum`) koydu, mobil onu ne okuyor ne yaziyordu. Bu
/// dosya iki kaynagin kim-kazanir kuralini uctan uca surer; taklit YALNIZ
/// HTTP adaptorundedir (tel uzerindeki govde olculur).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/core/startup/acilis_tercihleri.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/push/presentation/push_setup.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';

import 'helpers/bellek_depo.dart';
import 'package:mobile/src/core/gorunum/gorunum_modu.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'helpers/sahte_jwt.dart';

import 'helpers/sosyal_kapali.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

/// Girisi sunucuya inmeden karsilayan repo: rolu gomulu bir JWT'yi depoya
/// yazar — boylece `currentUserRoleProvider` GERCEK yoldan (token → claim)
/// rolu cozer, testte kestirme yapilmaz.
class _SahteAuthRepo implements AuthRepository {
  // (P149) Parolasiz giris ucu — bu sahtelerin olcumu parola yolundadir;
  // kod yolu kendi testinde surulur.
  @override
  Future<void> girisKoduIste(String telefon) async {}

  @override
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe = false,
  }) async {}

  _SahteAuthRepo(this._storage, this._role);

  final TokenStorage _storage;
  final UserRole _role;

  final girisler = <String>[];

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    girisler.add(phone);
    final tokens = TokenPair(
      accessToken: sahteJwt({'sub': 'u1', 'role': _role.wire}),
      refreshToken: 'r',
      tokenType: 'Bearer',
      expiresIn: 900,
    );
    await _storage.save(tokens);
    await _storage.saveRememberMe(rememberMe);
    return PhoneLoginResult(passwordSetupRequired: false, tokens: tokens);
  }

  @override
  Future<({String phone, String password})?> readSavedCredentials() async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _uygulama(BellekDepo depo, UserRole role,
    {AcilisTercihleri? tohum, required _Tel tel}) {
  final storage = TokenStorage(depo);
  return ProviderScope(
    overrides: [...sosyalKapali,
      secureStorageProvider.overrideWithValue(depo),
      // (P247 §7) TEL DIKISI: esitleme GERCEK `GorunumSunucu` + gercek Dio
      // ile kosar; taklit yalniz HTTP adaptorunde (tel uzerindeki govde).
      dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel),
      // (P154 / Asama 2) Tohum VERILMEZSE `acilisTercihleriProvider` null
      // kalir ve ilk-acilis yonlendirmesi HIC devreye girmez — mevcut
      // senaryolar (giris → rol ana ekrani) aynen surer.
      if (tohum != null) acilisTercihleriProvider.overrideWithValue(tohum),
      authRepositoryProvider
          .overrideWithValue(_SahteAuthRepo(storage, role)),
      // Kok widget'in izledigi eklenti-bagimli yan etkiler (baglanti dinleme,
      // FCM kaydi) testte kapali — acilis/giris yolu test ediliyor.
      outboxAutoSyncProvider.overrideWithValue(null),
      pushSetupProvider.overrideWithValue(null),
      scanOutboxProvider.overrideWith(_FakeOutbox.new),
      // Ana ekran veri uclari — ag'a cikilmaz.
      profileProvider.overrideWith((ref) async =>
          Profile(ad: 'Kerem', role: role.wire, aranabilir: false,
              birincil: true)),
      myAvatarUrlProvider.overrideWith((ref) async => null),
      tenantSettingsProvider.overrideWith((ref) async => const TenantSettings(
          tenantId: 't1', ad: 'Mavi Residence', kurulumTamamlandi: true)),
      unreadNotificationCountProvider.overrideWith((ref) async => 0),
      weatherProvider.overrideWith((ref) async => throw Exception('offline')),
      yoneticiIletisimProvider
          .overrideWith((ref) async => throw Exception('offline')),
      shiftsProvider.overrideWith((ref) async => const []),
      anaEkranKameralariProvider.overrideWith((ref) async => const []),
      kargoListProvider.overrideWith((ref) async => const []),
      sonDuyurularProvider.overrideWith((ref) async => const []),
      sonHareketlerProvider.overrideWith((ref) async => const []),
      icerdekiZiyaretciSayisiProvider.overrideWith((ref) async => 1),
      bugunkuAracGirisSayisiProvider.overrideWith((ref) async => 4),
      yeniIhlalSayisiProvider.overrideWith((ref) async => 2),
      aktifGorevSayisiProvider.overrideWith((ref) async => 6),
      uzerimdekiZimmetSayisiProvider.overrideWith((ref) async => 3),
      acikSikayetSayisiProvider.overrideWith((ref) async => 5),
      yaklasanEtkinlikSayisiProvider.overrideWith((ref) async => 2),
      toplamDaireSayisiProvider.overrideWith((ref) async => 48),
      financialSummaryProvider
          .overrideWith((ref) async => throw Exception('403')),
      otoparkDolulukProvider
          .overrideWith((ref) async => throw Exception('403')),
      acikDaireSikayetSayisiProvider.overrideWith((ref) async => 2),
      kendiDaireSikayetSayisiProvider.overrideWith((ref) async => 1),
      kendiGurultuSikayetSayisiProvider.overrideWith((ref) async => 0),
      myDuesProvider.overrideWith((ref) async => const []),
      visitorsListProvider.overrideWith((ref) async => const []),
    ],
    child: const TesisGuvenlikApp(),
  );
}

/// Sahte sunucu — TEL UZERINDEKI istekleri kaydeder. Hesaptaki gorunum
/// modunu tutar; `PATCH /me/gorunum` onu gunceller (web'in yaptigi gibi).
class _Tel implements HttpClientAdapter {
  _Tel({this.sunucu = 'standart', this.patchHata = false});

  String sunucu;
  bool patchHata;
  final istekler = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final govde = options.data == null ? '' : ' ${jsonEncode(options.data)}';
    istekler.add('${options.method} ${options.path}$govde');
    if (options.method == 'GET' && options.path == '/me') {
      return _json({'ad': 'Kerem', 'ui_gorunum': sunucu});
    }
    if (options.method == 'PATCH' && options.path == '/me/gorunum') {
      if (patchHata) return _json(const {'detail': 'x'}, 503);
      sunucu = (options.data as Map)['gorunum'] as String;
      return _json({'ad': 'Kerem', 'ui_gorunum': sunucu});
    }
    return _json(const {}, 404);
  }

  ResponseBody _json(Object govde, [int durum = 200]) =>
      ResponseBody.fromString(jsonEncode(govde), durum, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  List<String> get gorunumYazimlari =>
      [for (final i in istekler) if (i.startsWith('PATCH /me/gorunum')) i];

  @override
  void close({bool force = false}) {}
}

Future<void> _girisYap(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, '+905321112201');
  await tester.enterText(find.byType(TextFormField).last, 'Yonetici123!');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

int _karo() => find.byType(HizliErisimKarti).evaluate().length;

/// Uygulamayi AYNI depoyla acar — "uygulamayi kapatip yeniden actim".
/// Tohum `main()`in yaptigi gibi `runApp` oncesi depodan okunur.
Future<void> _ac(WidgetTester tester, BellekDepo depo, _Tel tel) async {
  // Onceki agaci tamamen sok: yeni ProviderScope = yeni surec.
  await tester.pumpWidget(const SizedBox());
  final tohum = await acilisTercihleriniOku(depo);
  await tester.pumpWidget(
      _uygulama(depo, UserRole.yonetici, tohum: tohum, tel: tel));
  await tester.pumpAndSettle();
}

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  const anahtar = 'ui.gorunum_modu';
  final ilkAcilisGecti = {rolSecimiKey: '1'};

  testWidgets('WEB\'DE "Buyuk" SECILMIS HESAP: giriste telefon da 4 karo',
      (tester) async {
    // KOK NEDEN KILIDI. P243 §4 ayari hesaba yazdi, mobil o alani hic
    // okumuyordu: web'de Buyuk secen kullanici telefonda 8 karo goruyordu.
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(sunucu: 'buyuk');
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(tel.istekler, contains('GET /me'));
    expect(_karo(), 4);
    // Hesaptan gelen deger yerel depoya da yazilir: bir sonraki acilisin
    // ILK KARESI dogru cizilir.
    expect(depo.kutu[anahtar], 'buyuk');
  });

  testWidgets('ILK ACILIS, hesap standart: 8 karo, sunucuya YAZILMAZ',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel();
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(_karo(), 8);
    expect(tel.gorunumYazimlari, isEmpty);
  });

  testWidgets('AYARDAN Buyuk sec -> 4 karo, TEL: PATCH {"gorunum":"buyuk"}; '
      'yeniden acinca ILK KAREDE 4', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel();
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(_karo(), 8);

    final kap = ProviderScope.containerOf(
        tester.element(find.byType(YoneticiHomeScreen)));
    kap.read(routerProvider).push(AppRoutes.settings);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.zoom_in));
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    expect(tel.gorunumYazimlari, ['PATCH /me/gorunum {"gorunum":"buyuk"}']);
    expect(depo.kutu[anahtar], 'buyuk');
    kap.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(_karo(), 4);

    // YENIDEN AC: tohum depodan okunur, mod ILK KAREDE buyuk.
    await _ac(tester, depo, tel);
    final kap2 = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)));
    expect(kap2.read(gorunumModuProvider), GorunumModu.buyuk);
    await _girisYap(tester);
    expect(_karo(), 4);
  });

  testWidgets('1.6.0\'DAN KALAN yerel "buyuk" (hic gonderilmemis) sunucunun '
      'varsayilaniyla EZILMEZ — once sunucuya gonderilir', (tester) async {
    // Duzeltmenin kendisi bir gerileme uretmesin: P230 secimi yalniz
    // cihaza yaziyordu; hesaptaki deger bu kullanicilar icin "standart".
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti, anahtar: 'buyuk'});
    final tel = _Tel(sunucu: 'standart');
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(_karo(), 4);
    expect(tel.gorunumYazimlari, ['PATCH /me/gorunum {"gorunum":"buyuk"}']);
    expect(tel.sunucu, 'buyuk');
  });

  testWidgets('ESITLENMIS cihaz: web\'de standarda donulduyse HESAP KAZANIR',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({
      ...ilkAcilisGecti,
      anahtar: 'buyuk',
      GorunumModuController.esitlikAnahtari: 'esit',
    });
    final tel = _Tel(sunucu: 'standart');
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(_karo(), 8);
    expect(tel.gorunumYazimlari, isEmpty);
    expect(depo.kutu[anahtar], 'standart');
  });

  testWidgets('CEVRIMDISI secim KAYBOLMAZ: PATCH basarisiz -> sonraki '
      'giriste yeniden gonderilir', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(patchHata: true);
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    final kap = ProviderScope.containerOf(
        tester.element(find.byType(YoneticiHomeScreen)));
    // `await` EDILMEZ: Dio zamanlayici kullanir, sahte zamanda beklemek
    // testi asar; ilerletmeyi pumpAndSettle yapar.
    unawaited(
        kap.read(gorunumModuProvider.notifier).ayarla(GorunumModu.buyuk));
    await tester.pumpAndSettle();
    expect(tel.sunucu, 'standart');
    expect(depo.kutu[GorunumModuController.esitlikAnahtari], 'bekliyor:u1');

    tel.patchHata = false;
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(_karo(), 4, reason: 'sunucunun eski "standart"i yerel secimi ezdi');
    expect(tel.sunucu, 'buyuk');
    expect(depo.kutu[GorunumModuController.esitlikAnahtari], 'esit');
  });

  testWidgets('BASKA KULLANICININ bekleyen secimi yeni hesaba YAZILMAZ',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({
      ...ilkAcilisGecti,
      anahtar: 'buyuk',
      GorunumModuController.esitlikAnahtari: 'bekliyor:baska-kullanici',
    });
    final tel = _Tel(sunucu: 'standart');
    await _ac(tester, depo, tel);
    await _girisYap(tester);
    expect(tel.gorunumYazimlari, isEmpty);
    expect(_karo(), 8);
  });
}
