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
      ],
      child: const MaterialApp(home: SahaHomeScreen(role: UserRole.security)),
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

  testWidgets('320x480: gercek vardiya YOKKEN de (mock taban) tasma yok',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Vardiya Durumu'), findsOneWidget);
  });
}
