import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';

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

Widget _app(UserRole role, {int pending = 0}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => Profile(
            ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(pending)),
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
        'Turlarım) + "Yakında" kartlari (Vardiya/Canlı Kamera) + FAB',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security));
      await tester.pumpAndSettle();

      expect(find.text('Merhaba, Mehmet'), findsOneWidget);
      expect(find.text('Güvenlik'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsOneWidget);
      expect(find.text('Turlarım'), findsOneWidget);
      expect(find.text('Olay Bildir'), findsOneWidget);
      // MISSING-BACKEND referans kartlari — pasif "Yakında".
      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Canlı Kamera'), findsOneWidget);
      expect(find.text('Yakında'), findsNWidgets(4)); // vardiya+plaka+ihlal+kamera
    });

    testWidgets('tesisGorevlisi: KVKK — Ziyaretçi/Kargo/Kamera YOK; Görevlerim '
        'VAR; yakinda YALNIZ Vardiya Durumu', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi));
      await tester.pumpAndSettle();

      expect(find.text('Tesis Görevlisi'), findsOneWidget);
      expect(find.text('Görevlerim'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsNothing);
      expect(find.text('Kargo'), findsNothing);
      expect(find.text('Canlı Kamera'), findsNothing);
      expect(find.text('Araç Plaka'), findsNothing);
      expect(find.text('Yakında'), findsOneWidget); // yalniz Vardiya Durumu
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
