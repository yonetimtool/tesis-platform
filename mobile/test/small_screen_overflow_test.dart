import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'helpers/l10n_test_app.dart';

/// Eski home_screen_overflow_test'in mirasi: KUCUK ekranda (320x480) en cok
/// bolumlu ekran (saha/security: serit + vardiya + son hareketler + kamera)
/// overflow uretmemeli ve icerigin sonu kaydirilarak erisilebilmeli.
class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

Widget _app({List<Shift> vardiyalar = const []}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
            ad: 'Mehmet', role: 'security', aranabilir: false)),
        scanOutboxProvider.overrideWith(_FakeOutbox.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 5),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        // Bolumler GERCEK uctan beslenir; testte aga cikmadan doldurulur.
        camerasProvider.overrideWith((ref) async => const [
              Camera(id: 'c1', ad: 'Ana Kapı', streamUrl: 'https://x/s.m3u8'),
            ]),
        icerdekiZiyaretciSayisiProvider.overrideWith((ref) async => 1),
        bugunkuAracGirisSayisiProvider.overrideWith((ref) async => 4),
        yeniIhlalSayisiProvider.overrideWith((ref) async => 2),
        sonHareketlerProvider.overrideWith((ref) async => [
              ActivityItem(
                id: 'ziyaretci_giris:z1',
                tur: ActivityTur.ziyaretciGiris,
                baslik: 'Ziyaretçi Girişi',
                altMetin: 'Ahmet Yılmaz — Daire 12',
                zaman: DateTime(2026, 7, 23, 10),
                kaynakId: 'z1',
              ),
            ]),
      ],
      child: l10nApp(SahaHomeScreen(role: UserRole.security)),
    );

void main() {
  testWidgets('320x480: security ana ekrani overflow uretmez; alttaki bolum '
      'kaydirilarak gorunur', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(vardiyalar: const [
      Shift(
          id: 'v1',
          ad: 'Sabah Vardiyası',
          baslangicSaat: '06:00',
          bitisSaat: '14:00',
          gunTipi: 'hafta_ici'),
    ]));
    await tester.pumpAndSettle();

    // Overflow ("BOTTOM OVERFLOWED BY ...") FlutterError olarak yakalanirdi.
    expect(tester.takeException(), isNull);
    expect(find.text('Merhaba, Mehmet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Canlı Kamera'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Canlı Kamera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320x480: vardiya YOKKEN (bolum cizilmez) de tasma yok',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Vardiya bolumu yok; serit karti (dar ekranda 2 sutuna dusen izgara
    // degil, yatay serit) yerinde durur.
    expect(find.text('Vardiya Durumu'), findsNothing);
    expect(find.text('Vardiya Durum'), findsOneWidget);
  });
}
