/// SOGUK ACILIS → GIRIS → ROL ANA EKRANI — GERCEK uygulama kokuyle.
///
/// NEDEN AYRI BIR TEST: diger testler ekranlari yalin `MaterialApp` icinde
/// cizer; [TesisGuvenlikApp] (main.dart) HIC cizilmiyordu. i18n turunda
/// eklenen `locale` / `localizationsDelegates` / `localeResolutionCallback`
/// baglamasi ve `aktifLocaleProvider` izlemesi tam da orada yasiyor — bu
/// yuzden acilis + giris + rol yonlendirmesi burada UCTAN UCA surulur.
library;

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
import 'package:mobile/src/features/auth/presentation/login_screen.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
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
import 'helpers/sahte_jwt.dart';

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

Widget _uygulama(BellekDepo depo, UserRole role) {
  final storage = TokenStorage(depo);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(depo),
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
      camerasProvider.overrideWith((ref) async => const []),
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

/// Giris yapar: telefon + parola doldurup giris butonuna basar.
///
/// Buton metni tur 8'de YERELLESTIRILDI (`girisYap`): bu dosya ar dilinde de
/// kostugu icin buton TIPTEN bulunur, metinden DEGIL — aksi halde Arapca
/// senaryo "Giriş yap" bulamayip duserdi.
Future<void> _girisYap(WidgetTester tester) async {
  await tester.enterText(
      find.byType(TextFormField).first, '+905321112201');
  await tester.enterText(find.byType(TextFormField).last, 'Yonetici123!');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  // Ekran uzunlugu: ana ekranlar uzun; tasma hatasi testi bozmasin.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('KAYITLI DIL varken (ui.locale=ar) giris + rol yonlendirmesi '
      'bozulmaz', (tester) async {
    tall(tester);
    await tester.pumpWidget(
        _uygulama(BellekDepo({'ui.locale': 'ar'}), UserRole.yonetici));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await _girisYap(tester);
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('soguk acilis LOGIN ekraninda baslar (auto-login yok)',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(_uygulama(BellekDepo(), UserRole.yonetici));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  group('4 ROL: giris → DOGRU ana ekran varyanti', () {
    testWidgets('yonetici → YoneticiHomeScreen', (tester) async {
      tall(tester);
      await tester.pumpWidget(_uygulama(BellekDepo(), UserRole.yonetici));
      await tester.pumpAndSettle();
      await _girisYap(tester);
      expect(find.byType(YoneticiHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('admin → YoneticiHomeScreen (yonetim duzeni)', (tester) async {
      tall(tester);
      await tester.pumpWidget(_uygulama(BellekDepo(), UserRole.admin));
      await tester.pumpAndSettle();
      await _girisYap(tester);
      final ekran =
          tester.widget<YoneticiHomeScreen>(find.byType(YoneticiHomeScreen));
      expect(ekran.role, UserRole.admin);
      expect(tester.takeException(), isNull);
    });

    testWidgets('security → SahaHomeScreen', (tester) async {
      tall(tester);
      await tester.pumpWidget(_uygulama(BellekDepo(), UserRole.security));
      await tester.pumpAndSettle();
      await _girisYap(tester);
      expect(find.byType(SahaHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resident → ResidentHomeScreen', (tester) async {
      tall(tester);
      await tester.pumpWidget(_uygulama(BellekDepo(), UserRole.resident));
      await tester.pumpAndSettle();
      await _girisYap(tester);
      expect(find.byType(ResidentHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
