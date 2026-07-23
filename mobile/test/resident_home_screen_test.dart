import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';

Widget _app() => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Çiğdem',
              role: 'resident',
              aranabilir: false,
            )),
      ],
      child: const MaterialApp(home: ResidentHomeScreen()),
    );

void main() {
  testWidgets('ResidentHomeScreen: profil adiyla karsilar + sakin alt-basligi '
      '+ one cikan kart gorunur', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Çiğdem'), findsOneWidget);
    expect(find.text('Site Sakini'), findsOneWidget);
    expect(find.text('Ziyaretçiler'), findsOneWidget);
  });
}
