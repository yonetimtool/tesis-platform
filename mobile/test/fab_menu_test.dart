import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';

/// WP2.4: merkez FAB artik dogrudan rota ACMAZ — rol-bazli olusturma menusu
/// (bottom sheet) acar.
class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

class _FakeNotifications extends NotificationsController {
  @override
  Future<List<AppNotification>> build() async => const [];
}

// NOT: `Override` tipi flutter_riverpod 3'te export edilmiyor — donus tipi
// bilerek yazilmadi (tip cikarimi internal tipe isimsiz baglanir).
// ignore: strict_top_level_inference
_common(String role) => [
      profileProvider.overrideWith(
          (ref) async => Profile(ad: 'X', role: role, aranabilir: false)),
      scanOutboxProvider.overrideWith(_FakeOutbox.new),
      unreadNotificationCountProvider.overrideWith((ref) async => 0),
      notificationsProvider.overrideWith(_FakeNotifications.new),
      shiftsProvider.overrideWith((ref) async => const []),
      financialSummaryProvider.overrideWith((ref) async =>
          const FinancialSummary(
              toplamGelirKurus: 0,
              toplamGiderKurus: 0,
              bakiyeKurus: 0,
              enYuksekGiderler: [])),
      acikSikayetSayisiProvider.overrideWith((ref) async => 0),
      myDuesProvider.overrideWith((ref) async => const []),
      kargoListProvider.overrideWith((ref) async => const []),
      visitorsListProvider.overrideWith((ref) async => const []),
      sonDuyurularProvider.overrideWith((ref) async => const []),
    ];

Future<void> _tapFab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home-fab')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('resident FAB: Talep / Arıza + Rezervasyon menusu', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _common('resident'),
      child: const MaterialApp(home: ResidentHomeScreen()),
    ));
    await tester.pumpAndSettle();
    await _tapFab(tester);

    expect(find.text('Talep / Arıza Bildir'), findsOneWidget);
    expect(find.text('Rezervasyon Yap'), findsOneWidget);
  });

  testWidgets('yonetici FAB: Duyuru + Görev + Destek (WP1)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _common('yonetici'),
      child: const MaterialApp(home: YoneticiHomeScreen()),
    ));
    await tester.pumpAndSettle();
    await _tapFab(tester);

    expect(find.text('Duyuru Yayınla'), findsOneWidget);
    expect(find.text('Görev Oluştur'), findsOneWidget);
    expect(find.text('Destek Talebi'), findsOneWidget);
  });

  testWidgets('security FAB: Olay/Şikayet + Görevlerim + Turlarım',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _common('security'),
      child: const MaterialApp(
          home: SahaHomeScreen(role: UserRole.security)),
    ));
    await tester.pumpAndSettle();
    await _tapFab(tester);

    expect(find.text('Olay Bildir'), findsNWidgets(2)); // FAB etiketi + menu
    expect(find.text('Görevlerim'), findsNWidgets(2)); // kart + menu
    expect(find.text('Turlarım'), findsNWidgets(2));
  });

  testWidgets('tesisGorevlisi FAB: Turlarım YOK (patrol RBAC disi)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _common('tesis_gorevlisi'),
      child: const MaterialApp(
          home: SahaHomeScreen(role: UserRole.tesisGorevlisi)),
    ));
    await tester.pumpAndSettle();
    await _tapFab(tester);

    expect(find.text('Olay Bildir'), findsNWidgets(2));
    expect(find.text('Turlarım'), findsNothing); // ne kart ne menu (RBAC)
  });
}
