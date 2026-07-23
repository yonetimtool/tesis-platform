import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/home_gate.dart';
import 'package:mobile/src/features/home/presentation/home_screen.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';

Widget _gate(UserRole role) => ProviderScope(
      overrides: [
        currentUserRoleProvider.overrideWith((ref) async => role),
        profileProvider.overrideWith((ref) async =>
            Profile(ad: 'X', role: role.wire, aranabilir: false)),
      ],
      child: const MaterialApp(home: HomeGate()),
    );

void main() {
  testWidgets('sakin rolu -> ResidentHomeScreen (yeni R1 ekrani)',
      (tester) async {
    await tester.pumpWidget(_gate(UserRole.resident));
    await tester.pumpAndSettle();
    expect(find.byType(ResidentHomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('sakin DISI (or. security) hala eski HomeScreen izgarasi',
      (tester) async {
    await tester.pumpWidget(_gate(UserRole.security));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ResidentHomeScreen), findsNothing);
  });
}
