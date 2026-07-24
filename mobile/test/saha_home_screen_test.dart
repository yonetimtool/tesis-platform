import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';

/// Depoya dokunmayan sahte kuyruk (path_provider yok) — bekleyen sayisi
/// kadar 'bekliyor' kaydi tasir.
class _FakeOutbox extends ScanOutbox {
  _FakeOutbox(this._pending);
  final int _pending;

  @override
  ScanOutboxState build() => ScanOutboxState(
        loaded: true,
        entries: [
          for (var i = 0; i < _pending; i++)
            OutboxEntry(
              idempotencyKey: 'k$i',
              nfcTagUid: 'uid',
              okutmaZamani: DateTime(2026, 1, 1),
              enqueuedAt: DateTime(2026, 1, 1),
            ),
        ],
      );
}

Widget _app(UserRole role, {int pending = 0, int unread = 0}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => Profile(
            ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(pending)),
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        shiftsProvider.overrideWith((ref) async => const [
              Shift(
                  id: 'v1',
                  ad: 'Sabah Vardiyası',
                  baslangicSaat: '06:00',
                  bitisSaat: '14:00',
                  gunTipi: 'hafta_ici'),
            ]),
        camerasProvider.overrideWith((ref) async => const [
              Camera(
                  id: 'c1', ad: 'Ana Kapı', streamUrl: 'https://x/s.m3u8'),
            ]),
      ],
      child: MaterialApp(home: SahaHomeScreen(role: role)),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('SahaHomeScreen — guvenlik + tesis gorevlisi (R3, gorevli.jpeg)', () {
    testWidgets('security: karsilama + "Güvenlik" + one cikanlar (Ziyaretçiler/'
        'Turlarım) + GERCEK Vardiya Durumu bolumu + kalan "Yakında" kartlari',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security));
      await tester.pumpAndSettle();

      expect(find.text('Merhaba, Mehmet'), findsOneWidget);
      expect(find.text('Güvenlik'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsOneWidget);
      expect(find.text('Turlarım'), findsOneWidget);
      expect(find.text('Olay Bildir'), findsOneWidget);
      // Vardiya Durumu ARTIK GERCEK bolum (/shifts) — comingSoon kart degil.
      // Cip durumu (AKTİF/PLANLANDI) gercek saate bagli oldugundan burada
      // ASSERT EDILMEZ (saat-flake); deterministik testi vardiya_section'da.
      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      // WP-F: Canlı Kamera artik GERCEK serit (bolum basligi + kamera adi);
      // Yakında'dan kaldirildi.
      expect(find.text('Canlı Kamera'), findsOneWidget); // serit basligi
      expect(find.text('Ana Kapı'), findsOneWidget); // serit karti
      // Kalan MISSING-BACKEND kartlari — pasif "Yakında" (Plaka + İhlaller).
      expect(find.text('Yakında'), findsNWidgets(2)); // plaka+ihlal
    });

    testWidgets('tesisGorevlisi: KVKK — Ziyaretçi/Kargo/Kamera YOK; Görevlerim '
        'VAR; vardiya GERCEK bolum; "Yakında" izgarasi HIC yok', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi));
      await tester.pumpAndSettle();

      expect(find.text('Tesis Görevlisi'), findsOneWidget);
      expect(find.text('Görevlerim'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsNothing);
      expect(find.text('Kargo'), findsNothing);
      expect(find.text('Canlı Kamera'), findsNothing);
      expect(find.text('Araç Plaka'), findsNothing);
      // Vardiya artik gercek; baska comingSoon kalmadi → izgara tamamen gizli.
      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('Yakında'), findsNothing);
      expect(find.text('Yakında Eklenecekler'), findsNothing);
    });

    testWidgets('security: okunmamis bildirim rozeti zil + sekmede gorunur '
        '(RBAC izinli rol)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNWidgets(2));
    });

    testWidgets('tesisGorevlisi: /notifications RBAC DISI — rozet HIC '
        'gorunmez (401 uretecek istek de atilmaz)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNothing);
    });

    testWidgets('outbox bekleyen > 0: Gönderim Kuyruğu kartinda sayac '
        '(eski ekran rozetinin karsiligi — regresyon yok)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, pending: 3));
      await tester.pumpAndSettle();

      expect(find.text('Gönderim Kuyruğu'), findsOneWidget);
      expect(find.text('3 bekleyen'), findsOneWidget);
    });
  });
}
