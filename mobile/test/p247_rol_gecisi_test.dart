/// (P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN (mobil).
///
/// GERCEK UYGULAMA KOKU (`OturumKoku` + `TesisGuvenlikApp`) ile surulur;
/// taklit YALNIZ HTTP adaptorundedir — tel uzerindeki govde olculur
/// (`POST /me/rol-gecis {"rol":..., "refresh_token":...}`). Kabin yeniden
/// kurulmasi da gercektir: gecisten sonra ProviderScope yenidir, eski
/// modun ekrani agacta KALMAZ.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/main.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/startup/acilis_tercihleri.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/jwt_claims.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/notifications/presentation/bildirim_rotasi.dart';
import 'package:mobile/src/features/panik/presentation/panik_takip_screen.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/push/domain/push_models.dart';
import 'package:mobile/src/features/push/presentation/push_registrar.dart';
import 'package:mobile/src/features/push/presentation/push_setup.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/sahte_jwt.dart';
import 'helpers/sosyal_kapali.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

/// Tepsiden tiklamayi elle tetiklemek icin (Firebase yok).
class _SahteRegistrar extends PushRegistrar {
  void tikla(PushMessageEvent e) => state = state.copyWith(sonTiklanan: e);
}

String _jeton(UserRole rol, {bool sakinModu = false}) => sahteJwt({
      'sub': 'u1',
      'tenant_id': 't1',
      'role': rol.wire,
      if (sakinModu) 'asil_rol': 'yonetici',
    });

/// Girisi sunucuya inmeden karsilar: verilen jetonu depoya yazar.
class _SahteAuthRepo implements AuthRepository {
  _SahteAuthRepo(this._storage, this._erisim);

  final TokenStorage _storage;
  final String _erisim;

  @override
  Future<void> girisKoduIste(String telefon) async {}

  @override
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe = false,
  }) async {}

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    final tokens = TokenPair(
      accessToken: _erisim,
      refreshToken: 'r-eski',
      tokenType: 'Bearer',
      expiresIn: 900,
    );
    await _storage.save(tokens);
    return PhoneLoginResult(passwordSetupRequired: false, tokens: tokens);
  }

  @override
  Future<({String phone, String password})?> readSavedCredentials() async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Sahte sunucu — TEL uzerindeki istekleri kaydeder.
class _Tel implements HttpClientAdapter {
  _Tel({required this.roller});

  List<String> roller;
  final istekler = <String>[];
  final gecisGovdeleri = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final govde = options.data == null ? '' : ' ${jsonEncode(options.data)}';
    istekler.add('${options.method} ${options.path}$govde');
    if (options.method == 'GET' && options.path == '/me') {
      return _json({'ad': 'Kerem', 'ui_gorunum': 'standart', 'roller': roller});
    }
    if (options.method == 'POST' && options.path == '/me/rol-gecis') {
      final g = Map<String, dynamic>.from(options.data as Map);
      gecisGovdeleri.add(g);
      final rol = UserRole.fromClaim(g['rol'] as String);
      return _json({
        'access_token':
            _jeton(rol, sakinModu: rol == UserRole.resident),
        'refresh_token': 'r-yeni-${rol.wire}',
        'token_type': 'Bearer',
        'expires_in': 900,
      });
    }
    return _json(const {}, 404);
  }

  ResponseBody _json(Object govde, [int durum = 200]) =>
      ResponseBody.fromString(jsonEncode(govde), durum, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

List<Override> _taklitler(BellekDepo depo, _Tel tel, String erisim) {
  final storage = TokenStorage(depo);
  return [
    ...sosyalKapali,
    secureStorageProvider.overrideWithValue(depo),
    dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel),
    authRepositoryProvider.overrideWithValue(_SahteAuthRepo(storage, erisim)),
    outboxAutoSyncProvider.overrideWithValue(null),
    pushSetupProvider.overrideWithValue(null),
    pushRegistrarProvider.overrideWith(_SahteRegistrar.new),
    scanOutboxProvider.overrideWith(_FakeOutbox.new),
    profileProvider.overrideWith((ref) async => const Profile(
        ad: 'Kerem',
        role: 'yonetici',
        aranabilir: false,
        birincil: false,
        turGoruldu: true)),
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
    otoparkDolulukProvider.overrideWith((ref) async => throw Exception('403')),
    acikDaireSikayetSayisiProvider.overrideWith((ref) async => 2),
    kendiDaireSikayetSayisiProvider.overrideWith((ref) async => 1),
    kendiGurultuSikayetSayisiProvider.overrideWith((ref) async => 0),
    myDuesProvider.overrideWith((ref) async => const []),
    visitorsListProvider.overrideWith((ref) async => const []),
  ];
}

/// Uygulamayi GERCEK kokle acar ve giris yapar.
Future<void> _acVeGir(
  WidgetTester tester,
  BellekDepo depo,
  _Tel tel, {
  String? erisim,
}) async {
  await tester.pumpWidget(const SizedBox());
  final tohum = await acilisTercihleriniOku(depo);
  await tester.pumpWidget(OturumKoku(
    tercihler: tohum,
    tercihOku: () => acilisTercihleriniOku(depo),
    ekOverrides:
        _taklitler(depo, tel, erisim ?? _jeton(UserRole.yonetici)),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '+905321112201');
  await tester.enterText(find.byType(TextFormField).last, 'Yonetici123!');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

/// Etkin dilin metinleri (test cihazinin dili Turkce olmayabilir).
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Navigator).first));

Future<void> _pompala(WidgetTester tester, int kez) async {
  for (var i = 0; i < kez; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer _kap(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// Sakin modunda asla gorunmemesi gereken YONETIM girisleri.
const _yonetimGirisleri = {
  HomeMenuEntry.patrolTracking,
  HomeMenuEntry.taskTracking,
  HomeMenuEntry.tahsilat,
  HomeMenuEntry.borclular,
  HomeMenuEntry.gider,
  HomeMenuEntry.sayacOkuma,
  HomeMenuEntry.budget,
  HomeMenuEntry.financialSummary,
  HomeMenuEntry.reports,
  HomeMenuEntry.personel,
  HomeMenuEntry.sakinler,
  HomeMenuEntry.davetler,
  HomeMenuEntry.gurultuUyarilari,
  HomeMenuEntry.integrations,
  HomeMenuEntry.diyafon,
  HomeMenuEntry.binaDuzenleme,
  HomeMenuEntry.daireTanimlari,
  HomeMenuEntry.taskCategories,
  HomeMenuEntry.kurulum,
  HomeMenuEntry.otopark,
  HomeMenuEntry.ihlaller,
  HomeMenuEntry.panikTakip,
  HomeMenuEntry.vardiyalar,
  HomeMenuEntry.complaints,
  HomeMenuEntry.bakim,
};

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final ilkAcilisGecti = {rolSecimiKey: '1'};

  group('karar: rolGecisliHedef (saf)', () {
    const iki = [UserRole.yonetici, UserRole.resident];

    test('sakin modunda YONETIM hedefi -> yonetici moduna gecis', () {
      for (final tip in ['panik_alarm', 'bakim_gecikti', 'entegrasyon_koptu']) {
        final k = rolGecisliHedef({'tip': tip}, UserRole.resident, iki);
        expect(k, isNotNull, reason: tip);
        expect(k!.gecis, UserRole.yonetici, reason: tip);
      }
      expect(
          rolGecisliHedef({'tip': 'panik_alarm'}, UserRole.resident, iki)!
              .rota,
          AppRoutes.panikTakip);
    });

    test('yonetici modunda SAKIN hedefi (aidat) -> sakin moduna gecis', () {
      final k = rolGecisliHedef({'tip': 'aidat_borc'}, UserRole.yonetici, iki);
      expect(k!.gecis, UserRole.resident);
      expect(k.rota, AppRoutes.myDues);
    });

    test('aktif rolde erisilebilen hedef -> gecis YOK', () {
      final k = rolGecisliHedef({'tip': 'panik_alarm'}, UserRole.yonetici, iki);
      expect(k!.gecis, isNull);
      expect(k.rota, AppRoutes.panikTakip);
    });

    test('TEK ROLDE gecis yok (eski davranis: null)', () {
      expect(
          rolGecisliHedef(
              {'tip': 'aidat_borc'}, UserRole.yonetici, const [UserRole.yonetici]),
          isNull);
      expect(rolGecisliHedef({'tip': 'aidat_borc'}, UserRole.yonetici, const []),
          isNull);
      // Guvenlik gorevlisi: rol listesinde olmayan bir role ASLA gecmez.
      expect(
          rolGecisliHedef({'tip': 'aidat_borc'}, UserRole.security, iki),
          isNull);
    });
  });

  group('hedef_rol (P247 §5) — bildirimin MODU once gelir', () {
    const iki = [UserRole.yonetici, UserRole.resident];

    test('yonetici modunda kargo + hedef_rol=resident -> sakine gecis', () {
      // Kargo yoneticide de erisilebilir (yonetim gorunumu) — tip tek
      // basina yetmez; sunucunun soyledigi mod kazanir.
      final k = rolGecisliHedef(
          {'tip': 'kargo', 'hedef_rol': 'resident'}, UserRole.yonetici, iki);
      expect(k!.gecis, UserRole.resident);
      expect(k.rota, AppRoutes.kargo);
      expect(modDisiHedef(UserRole.resident, UserRole.yonetici), isTrue);
    });

    test('sakin modunda panik_alarm + hedef_rol=yonetici -> yoneticiye', () {
      final k = rolGecisliHedef({'tip': 'panik_alarm', 'hedef_rol': 'yonetici'},
          UserRole.resident, iki);
      expect(k!.gecis, UserRole.yonetici);
      expect(k.rota, AppRoutes.panikTakip);
    });

    test('hedef_rol aktif modla ayni -> gecis yok; tek rolde yok sayilir', () {
      final ayni = rolGecisliHedef(
          {'tip': 'kargo', 'hedef_rol': 'resident'}, UserRole.resident, iki);
      expect(ayni!.gecis, isNull);
      final tek = rolGecisliHedef({'tip': 'kargo', 'hedef_rol': 'resident'},
          UserRole.yonetici, const [UserRole.yonetici]);
      expect(tek?.gecis, isNull);
      // Saha rolleri icin roller hic sorulmaz.
      expect(modDisiHedef(UserRole.yonetici, UserRole.security), isFalse);
    });

    test('LISTE satiri: hedef_rol yok -> tipten (SAKIN_KIMLIKLERI aynasi)', () {
      const kargo = AppNotification(id: 'n1', tip: 'kargo');
      expect(bildirimHedefRolu(kargo), UserRole.resident);
      final k = bildirimHedefiRolGecisli(kargo, UserRole.yonetici, iki);
      expect(k!.gecis, UserRole.resident);
      const bakim = AppNotification(id: 'n2', tip: 'bakim_gecikti');
      expect(bildirimHedefRolu(bakim), UserRole.yonetici);
      expect(bildirimHedefiRolGecisli(bakim, UserRole.resident, iki)!.gecis,
          UserRole.yonetici);
    });
  });

  test('sakin menusu YONETIM girisi icermez; yonetim kumesi yoneticide var',
      () {
    final sakin = homeMenuForRole(UserRole.resident).toSet();
    expect(sakin.intersection(_yonetimGirisleri), isEmpty);
    final yonetici = homeMenuForRole(UserRole.yonetici).toSet();
    // Kume anlamli olsun: her giris gercekten yoneticinin menusunde.
    expect(_yonetimGirisleri.difference(yonetici), isEmpty);
    // Erisim suzgeci de ayni: sakin modunda yonetim rotasi erisilemez.
    for (final r in [AppRoutes.panikTakip, AppRoutes.bakim, AppRoutes.complaints]) {
      expect(rotaErisilebilir(r, UserRole.resident), isFalse, reason: r);
    }
  });

  testWidgets('roller=2: avatar menusunde Yonetici (isaretli) + Sakin',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['yonetici', 'resident']);
    await _acVeGir(tester, depo, tel);
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-avatar')));
    await tester.pumpAndSettle();
    final yon = find.byKey(const Key('rol-gecis-yonetici'));
    final sak = find.byKey(const Key('rol-gecis-sakin'));
    expect(yon, findsOneWidget);
    expect(sak, findsOneWidget);
    expect(find.descendant(of: yon, matching: find.byIcon(Icons.check)),
        findsOneWidget);
    expect(find.descendant(of: sak, matching: find.byIcon(Icons.check)),
        findsNothing);
    // Aktif mod dokunulamaz.
    expect(tester.widget<ListTile>(yon).onTap, isNull);
  });

  testWidgets('roller=1 (daire bagi yok): menude secenek YOK', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['yonetici']);
    await _acVeGir(tester, depo, tel);
    await tester.tap(find.byKey(const Key('home-avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rol-gecis-yonetici')), findsNothing);
    expect(find.byKey(const Key('rol-gecis-sakin')), findsNothing);
  });

  testWidgets(
      'Sakin sec -> TEL: POST /me/rol-gecis {rol:resident, refresh_token}; '
      'kap yeniden kurulur, sakin ana ekrani, oturum surer', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['yonetici', 'resident']);
    await _acVeGir(tester, depo, tel);
    final eskiKap = _kap(tester);
    await tester.tap(find.byKey(const Key('home-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rol-gecis-sakin')));
    // SnackBar 4 sn yasar: pumpAndSettle onu gecip gidebilir — once
    // sinirli pompa ile bildirimi olc, sonra otur.
    await _pompala(tester, 10);
    expect(find.text(_l10n(tester).rolGecildiSakin), findsOneWidget);
    await tester.pumpAndSettle();

    expect(tel.gecisGovdeleri, [
      {'rol': 'resident', 'refresh_token': 'r-eski'},
    ]);
    final erisim = await TokenStorage(depo).readAccessToken();
    expect(decodeJwtClaims(erisim!)!['role'], 'resident');
    expect(await TokenStorage(depo).readRefreshToken(), 'r-yeni-resident');
    // YENI KAP: eski saglayici kabi atildi.
    expect(identical(_kap(tester), eskiKap), isFalse);
    // Karisik durum yok: yonetici ekrani agacta HIC yok; login'e dusmedi.
    expect(find.byType(YoneticiHomeScreen), findsNothing);
    expect(find.byType(ResidentHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('rol-gecis-perdesi')), findsNothing);
    // Son mod kullanici basina hatirlandi (soguk acilista geri yuklenir).
    expect(depo.kutu['rol.son_mod.u1'], 'resident');

    // Geri: Yonetici -> yonetici paneli.
    await tester.tap(find.byKey(const Key('home-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rol-gecis-yonetici')));
    await tester.pumpAndSettle();
    expect(tel.gecisGovdeleri.last,
        {'rol': 'yonetici', 'refresh_token': 'r-yeni-resident'});
    expect(find.byType(ResidentHomeScreen), findsNothing);
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
    expect(depo.kutu['rol.son_mod.u1'], 'yonetici');
  });

  testWidgets('SOGUK ACILIS: son mod sakinse giristen sonra sessizce sakin',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti, 'rol.son_mod.u1': 'resident'});
    final tel = _Tel(roller: ['yonetici', 'resident']);
    await _acVeGir(tester, depo, tel);
    expect(tel.gecisGovdeleri, [
      {'rol': 'resident', 'refresh_token': 'r-eski'},
    ]);
    expect(find.byType(ResidentHomeScreen), findsOneWidget);
    expect(find.byType(YoneticiHomeScreen), findsNothing);
    // Kullanici bir sey secmedi: bildirim YOK.
    expect(find.text(_l10n(tester).rolGecildiSakin), findsNothing);
  });

  testWidgets('SOGUK ACILIS: son mod sakin ama daire bagi kopmus -> yonetici',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti, 'rol.son_mod.u1': 'resident'});
    final tel = _Tel(roller: ['yonetici']);
    await _acVeGir(tester, depo, tel);
    expect(tel.gecisGovdeleri, isEmpty);
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
  });

  testWidgets(
      'PUSH dokunmasi: sakin modunda YONETIM tipi -> otomatik yonetici '
      'moduna gecis + hedef', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['yonetici', 'resident']);
    await _acVeGir(tester, depo, tel,
        erisim: _jeton(UserRole.resident, sakinModu: true));
    expect(find.byType(ResidentHomeScreen), findsOneWidget);

    final kap = _kap(tester);
    (kap.read(pushRegistrarProvider.notifier) as _SahteRegistrar)
        .tikla(const PushMessageEvent(data: {'tip': 'panik_alarm'}));
    // Panik ekrani zamanlayici tasir: pumpAndSettle yerine sinirli pompa.
    await _pompala(tester, 20);

    expect(tel.gecisGovdeleri, [
      {'rol': 'yonetici', 'refresh_token': 'r-eski'},
    ]);
    final yeniKap = _kap(tester);
    expect(identical(yeniKap, kap), isFalse);
    final erisim = await TokenStorage(depo).readAccessToken();
    expect(decodeJwtClaims(erisim!)!['role'], 'yonetici');
    // Hedef ekran YENI kapta, ana ekranin USTUNE acildi.
    expect(find.byType(PanikTakipScreen), findsOneWidget);
    expect(yeniKap.read(routerProvider).canPop(), isTrue);
    expect(find.text(_l10n(tester).rolGecildiYonetici), findsOneWidget);
    // Testin kapanisi: bekleyen zamanlayicilar kalmasin.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'PUSH dokunmasi: yonetici modunda kargo + hedef_rol=resident -> '
      'sakin moduna gecis (TEL)', (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['yonetici', 'resident']);
    await _acVeGir(tester, depo, tel);
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
    final kap = _kap(tester);
    (kap.read(pushRegistrarProvider.notifier) as _SahteRegistrar).tikla(
        const PushMessageEvent(data: {'tip': 'kargo', 'hedef_rol': 'resident'}));
    await _pompala(tester, 20);
    expect(tel.gecisGovdeleri, [
      {'rol': 'resident', 'refresh_token': 'r-eski'},
    ]);
    expect(identical(_kap(tester), kap), isFalse);
    expect(find.byType(YoneticiHomeScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('PUSH dokunmasi: TEK ROLLU sakin -> gecis cagrisi YOK',
      (tester) async {
    tall(tester);
    final depo = BellekDepo({...ilkAcilisGecti});
    final tel = _Tel(roller: ['resident']);
    await _acVeGir(tester, depo, tel, erisim: _jeton(UserRole.resident));
    final kap = _kap(tester);
    (kap.read(pushRegistrarProvider.notifier) as _SahteRegistrar)
        .tikla(const PushMessageEvent(data: {'tip': 'panik_alarm'}));
    await tester.pumpAndSettle();
    expect(tel.gecisGovdeleri, isEmpty);
    expect(identical(_kap(tester), kap), isTrue);
    expect(find.byType(ResidentHomeScreen), findsOneWidget);
    unawaited(Future<void>.value());
  });
}
