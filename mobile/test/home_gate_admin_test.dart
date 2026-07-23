import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/admin_home_screen.dart';
import 'package:mobile/src/features/home/presentation/home_gate.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

Widget _gate(UserRole role) => ProviderScope(
      overrides: [
        currentUserRoleProvider.overrideWith((ref) async => role),
        profileProvider.overrideWith((ref) async =>
            Profile(ad: 'X', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(_FakeOutbox.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
      ],
      child: const MaterialApp(home: HomeGate()),
    );

void main() {
  testWidgets('admin -> AdminHomeScreen (eski izgara HomeScreen emekli)',
      (tester) async {
    await tester.pumpWidget(_gate(UserRole.admin));
    await tester.pumpAndSettle();
    expect(find.byType(AdminHomeScreen), findsOneWidget);
  });

  testWidgets('unknown (rol cozulmeden, saniye alti) -> yalin bekleme '
      'ekrani; hicbir rol ekrani/kart YOK', (tester) async {
    await tester.pumpWidget(_gate(UserRole.unknown));
    await tester.pump(); // ilk kare — rol "cozulmus" ama unknown
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AdminHomeScreen), findsNothing);
    expect(find.text('Duyurular'), findsNothing);
  });
}
