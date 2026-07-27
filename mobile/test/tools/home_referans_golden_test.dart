/// GORSEL OZ-DENETIM araci — uc rol ana ekranini PNG olarak uretir; ciktilar
/// docs/design-refs/ altindaki referans gorsellerle yan yana karsilastirilir.
///
/// Calistirma:
/// ```
/// flutter test --dart-define=HOME_GOLDEN=true --update-goldens \
///   test/tools/home_referans_golden_test.dart
/// ```
/// Ciktilar: test/tools/goldens/{gorevli,site_sakini,yonetici}.png
///
/// Bu bir REGRESYON testi DEGILDIR: golden dosyalari tasarim denetimi icin
/// uretilen yerel ciktilardir (git'e girmez, bkz. .gitignore). Font/Skia
/// surumune duyarli olduklari icin normal `flutter test` kosusunda ATLANIR —
/// yalniz yukaridaki HOME_GOLDEN tanimiyla calisir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/parking_occupancy.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/weather/domain/weather_models.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';
import '../helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

class _FakeNotifications extends NotificationsController {
  @override
  Future<List<AppNotification>> build() async => const [];
}

/// Uzak uclar TEMSILI veriyle doldurulur. (Ana ekran artik mock taban
/// TASIMAZ — uc kapaliysa kartlar iskelet/'—' gosterir ve gorsel denetim
/// anlamsizlasirdi. Buradaki degerler yalniz bu araca aittir; uygulamada
/// hicbir sabit sayi YOKTUR.)
List<Object> _temsili(String ad, String role) => [
      profileProvider.overrideWith(
          (ref) async => Profile(ad: ad, role: role, aranabilir: false)),
      myAvatarUrlProvider.overrideWith((ref) async => null),
      scanOutboxProvider.overrideWith(_FakeOutbox.new),
      notificationsProvider.overrideWith(_FakeNotifications.new),
      unreadNotificationCountProvider.overrideWith((ref) async => 5),
      weatherProvider.overrideWith(
          (ref) async => const Weather(sicaklikC: 24, durum: 'acik',
              konumAd: 'İstanbul')),
      tenantSettingsProvider.overrideWith(
          (ref) async => const TenantSettings(tenantId: 't1', ad: 'Mavi Residence')),
      shiftsProvider.overrideWith((ref) async => const [
            Shift(
                id: 'v1',
                ad: 'Sabah Vardiyası',
                baslangicSaat: '06:00',
                bitisSaat: '14:00',
                gunTipi: 'hafta_ici'),
            Shift(
                id: 'v2',
                ad: 'Öğle Vardiyası',
                baslangicSaat: '14:00',
                bitisSaat: '22:00',
                gunTipi: 'her_gun'),
            Shift(
                id: 'v3',
                ad: 'Gece Vardiyası',
                baslangicSaat: '22:00',
                bitisSaat: '06:00',
                gunTipi: 'her_gun'),
          ]),
      camerasProvider.overrideWith((ref) async => const [
            Camera(id: 'c1', ad: 'Ana Giriş', streamUrl: 'https://x/1.m3u8'),
            Camera(id: 'c2', ad: 'Otopark', streamUrl: 'https://x/2.m3u8'),
          ]),
      kargoListProvider.overrideWith((ref) async => const []),
      visitorsListProvider.overrideWith((ref) async => const []),
      myDuesProvider.overrideWith((ref) async => [
            MyDuesUnit(
              unitId: 'u1',
              no: 'A-12',
              tahakkukKurus: 125000,
              odenenKurus: 125000,
              bakiyeKurus: 0,
              assessments: [
                DuesAssessment(
                    donem: '2026-07',
                    tutarKurus: 125000,
                    sonOdemeTarihi: DateTime(2026, 8, 5)),
              ],
              payments: [
                DuesPayment(
                  tutarKurus: 125000,
                  odemeZamani: DateTime(2026, 7, 5),
                  yontem: 'elden',
                  durum: 'basarili',
                ),
              ],
            ),
          ]),
      sonDuyurularProvider.overrideWith((ref) async => [
            Announcement(
              id: 'd1',
              baslik: 'Bahçe Düzenlemesi',
              govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
              olusturanUserId: 'y1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ]),
      financialSummaryProvider.overrideWith((ref) async => const FinancialSummary(
            toplamGelirKurus: 24875000,
            toplamGiderKurus: 10000000,
            bakiyeKurus: 14875000,
            enYuksekGiderler: [],
            tahsilat: TahsilatOzet(
              tahakkukKurus: 28900000,
              tahsilatKurus: 24875000,
              gecikenDaireSayisi: 7,
              tahsilatOraniYuzde: 86,
            ),
          )),
      acikSikayetSayisiProvider.overrideWith((ref) async => 8),
      toplamDaireSayisiProvider.overrideWith((ref) async => 52),
      aktifGorevSayisiProvider.overrideWith((ref) async => 6),
      acikDaireSikayetSayisiProvider.overrideWith((ref) async => 3),
      kendiDaireSikayetSayisiProvider.overrideWith((ref) async => 1),
      kendiGurultuSikayetSayisiProvider.overrideWith((ref) async => 2),
      icerdekiZiyaretciSayisiProvider.overrideWith((ref) async => 3),
      bugunkuAracGirisSayisiProvider.overrideWith((ref) async => 12),
      yeniIhlalSayisiProvider.overrideWith((ref) async => 2),
      otoparkDolulukProvider.overrideWith((ref) async =>
          const ParkingOccupancy(kapasite: 120, dolu: 78, oran: 65)),
      sonHareketlerProvider.overrideWith((ref) async => _hareketler),
      yoneticiIletisimProvider
          .overrideWith((ref) async => throw Exception('offline')),
    ];

/// Gorsel denetim icin temsili "Son Hareketler" satirlari.
final _hareketler = [
  ActivityItem(
    id: 'talep:t1',
    tur: ActivityTur.talep,
    baslikKimlik: AkisBaslik.talepAcik,
    veri: const {'baslik': 'Asansör arızası'},
    zaman: DateTime.now().subtract(const Duration(minutes: 20)),
    renk: ActivityRenk.uyari,
    kaynakId: 't1',
  ),
  ActivityItem(
    id: 'gorev_tamamlama:c1',
    tur: ActivityTur.gorevTamamlama,
    baslikKimlik: AkisBaslik.gorevTamamlama,
    veri: const {'ad': 'Çöp toplama'},
    zaman: DateTime.now().subtract(const Duration(hours: 2)),
    renk: ActivityRenk.olumlu,
    kaynakId: 'c1',
  ),
  ActivityItem(
    id: 'aidat_odeme:o1',
    tur: ActivityTur.aidatOdeme,
    baslikKimlik: AkisBaslik.aidatOdeme,
    veri: const {'daire': 'A-12', 'tutar_kurus': 125000},
    zaman: DateTime.now().subtract(const Duration(days: 1)),
    renk: ActivityRenk.olumlu,
    kaynakId: 'o1',
  ),
];

Future<void> _cek(
  WidgetTester tester, {
  required String ad,
  required String role,
  required Widget ekran,
  required String dosya,
}) async {
  // Referans gorsellerin oraniyla ayni: uzun telefon ekrani (tek karede tum
  // bolumler gorunsun).
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: _temsili(ad, role).cast(),
    // Altin gorseller TURKCE'ye SABIT (bkz. dosya basligi).
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: ekran,
    ),
  ));
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$dosya.png'),
  );
}

/// Ekran goruntusu uretimi yalniz acikca istendiginde calisir.
const _aktif = bool.fromEnvironment('HOME_GOLDEN');

void main() {
  testWidgets('gorevli ana ekrani', skip: !_aktif, (tester) async {
    await _cek(tester,
        ad: 'Kerem',
        role: 'security',
        ekran: const SahaHomeScreen(role: UserRole.security),
        dosya: 'gorevli');
  });

  testWidgets('site sakini ana ekrani', skip: !_aktif, (tester) async {
    await _cek(tester,
        ad: 'Çiğdem Hanım',
        role: 'resident',
        ekran: const ResidentHomeScreen(),
        dosya: 'site_sakini');
  });

  testWidgets('yonetici ana ekrani', skip: !_aktif, (tester) async {
    await _cek(tester,
        ad: 'Kerem',
        role: 'yonetici',
        ekran: const YoneticiHomeScreen(),
        dosya: 'yonetici');
  });
}
