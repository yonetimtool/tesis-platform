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
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
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

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

class _FakeNotifications extends NotificationsController {
  @override
  Future<List<AppNotification>> build() async => const [];
}

/// Tum uzak uclar KAPALI → ekran mock tabaniyla, yani referans gorsellerin
/// degerleriyle cizilir (karsilastirma birebir yapilabilsin diye).
List<Object> _offline(String ad, String role) => [
      profileProvider.overrideWith(
          (ref) async => Profile(ad: ad, role: role, aranabilir: false)),
      myAvatarUrlProvider.overrideWith((ref) async => null),
      scanOutboxProvider.overrideWith(_FakeOutbox.new),
      notificationsProvider.overrideWith(_FakeNotifications.new),
      unreadNotificationCountProvider.overrideWith((ref) async => 5),
      weatherProvider.overrideWith((ref) async => throw Exception('offline')),
      tenantSettingsProvider
          .overrideWith((ref) async => throw Exception('offline')),
      shiftsProvider.overrideWith((ref) async => const []),
      camerasProvider.overrideWith((ref) async => const []),
      kargoListProvider.overrideWith((ref) async => const []),
      visitorsListProvider.overrideWith((ref) async => const []),
      myDuesProvider.overrideWith((ref) async => const []),
      sonDuyurularProvider.overrideWith((ref) async => const []),
      financialSummaryProvider
          .overrideWith((ref) async => throw Exception('offline')),
      acikSikayetSayisiProvider
          .overrideWith((ref) async => throw Exception('offline')),
      yoneticiIletisimProvider
          .overrideWith((ref) async => throw Exception('offline')),
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
    overrides: _offline(ad, role).cast(),
    child: MaterialApp(debugShowCheckedModeBanner: false, home: ekran),
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
