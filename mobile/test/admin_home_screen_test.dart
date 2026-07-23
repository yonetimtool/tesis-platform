import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/admin_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';

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

Widget _app({int pending = 0, int unread = 0}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
            ad: 'Acme Admin', role: 'admin', aranabilir: false)),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(pending)),
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
      ],
      child: const MaterialApp(home: AdminHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('AdminHomeScreen: karsilama + "Platform Admin" + one cikan '
      'kartlar + FAB "Olay Bildir"', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Acme Admin'), findsOneWidget);
    expect(find.text('Platform Admin'), findsOneWidget);
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Görüntüleme İzni'), findsOneWidget);
    expect(find.text('Olay Bildir'), findsOneWidget);
    expect(find.text('Tüm Modüller'), findsOneWidget);
  });

  testWidgets('outbox bekleyen + okunmamis bildirim: sayac ve rozetler '
      '(eski ekran rozet regresyonu yok; admin /notifications RBAC-izinli)',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(pending: 2, unread: 4));
    await tester.pumpAndSettle();

    expect(find.text('2 bekleyen'), findsOneWidget);
    expect(find.text('4'), findsNWidgets(2)); // zil + sekme rozeti
  });
}
