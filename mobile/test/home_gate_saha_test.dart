import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/home_gate.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
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
      ],
      child: const MaterialApp(home: HomeGate()),
    );

void main() {
  for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
    testWidgets('${role.wire} -> SahaHomeScreen (R3, rol parametresiyle)',
        (tester) async {
      await tester.pumpWidget(_gate(role));
      await tester.pumpAndSettle();
      final screen =
          tester.widget<SahaHomeScreen>(find.byType(SahaHomeScreen));
      expect(screen.role, role);
    });
  }
}
