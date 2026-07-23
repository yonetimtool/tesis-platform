import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';

/// Eski home_screen_overflow_test'in mirasi: KUCUK ekranda (320x480) en cok
/// bolumlu yeni ekran (saha/security: izgara + vardiya + yakinda + tum
/// moduller) overflow uretmemeli; icerigin sonu kaydirilarak erisilebilir.
class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

void main() {
  testWidgets('320x480: security ana ekrani overflow uretmez; "Tüm Modüller" '
      'kaydirilarak gorunur', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
            ad: 'Mehmet', role: 'security', aranabilir: false)),
        scanOutboxProvider.overrideWith(_FakeOutbox.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 5),
        shiftsProvider.overrideWith((ref) async => const [
              Shift(
                  id: 'v1',
                  ad: 'Sabah Vardiyası',
                  baslangicSaat: '06:00',
                  bitisSaat: '14:00',
                  gunTipi: 'hafta_ici'),
            ]),
      ],
      child: const MaterialApp(home: SahaHomeScreen(role: UserRole.security)),
    ));
    await tester.pumpAndSettle();

    // Overflow ("BOTTOM OVERFLOWED BY ...") FlutterError olarak yakalanirdi.
    expect(tester.takeException(), isNull);
    expect(find.text('Merhaba, Mehmet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Tüm Modüller'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tüm Modüller'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
