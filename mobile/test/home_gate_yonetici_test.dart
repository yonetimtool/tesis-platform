import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/home_gate.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/tenant/presentation/setup_tenant_screen.dart';

Widget _gate({required bool birincil, required bool kurulum}) => ProviderScope(
      overrides: [
        currentUserRoleProvider
            .overrideWith((ref) async => UserRole.yonetici),
        profileProvider.overrideWith((ref) async => Profile(
            ad: 'Kerem',
            role: 'yonetici',
            aranabilir: false,
            birincil: birincil)),
        tenantSettingsProvider.overrideWith((ref) async => TenantSettings(
            tenantId: 't1',
            ad: 'Mavi Residence',
            kurulumTamamlandi: kurulum)),
      ],
      child: const MaterialApp(home: HomeGate()),
    );

void main() {
  testWidgets('yonetici (birincil, kurulum tamam) -> YoneticiHomeScreen (R2)',
      (tester) async {
    await tester.pumpWidget(_gate(birincil: true, kurulum: true));
    await tester.pumpAndSettle();
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
  });

  testWidgets('yonetici (birincil DEGIL) -> dogrudan YoneticiHomeScreen',
      (tester) async {
    await tester.pumpWidget(_gate(birincil: false, kurulum: false));
    await tester.pumpAndSettle();
    expect(find.byType(YoneticiHomeScreen), findsOneWidget);
  });

  testWidgets('BIRINCIL yonetici + kurulum TAMAMLANMADI -> SetupTenantScreen '
      'kapisi KORUNUR', (tester) async {
    await tester.pumpWidget(_gate(birincil: true, kurulum: false));
    await tester.pumpAndSettle();
    expect(find.byType(SetupTenantScreen), findsOneWidget);
    expect(find.byType(YoneticiHomeScreen), findsNothing);
  });
}
