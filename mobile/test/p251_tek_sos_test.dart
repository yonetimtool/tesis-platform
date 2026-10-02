/// (P251 §9) SOS TEK KEZ — simge "SOS" harfleriydi, yanina "SOS" yazisi
/// ekleniyordu ("SOS SOS"). Simdi: tek gorunur yazi, ekran okuyucuda
/// "Acil durum", dokunma hedefi en az 48x48.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_drawer.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

void main() {
  testWidgets('cekmecede TEK SOS: bir yazi, simge yok, ad "Acil durum", 48x48',
      (tester) async {
    final handle = tester.ensureSemantics();
    final rotalar = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(BellekDepo()),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(Scaffold(
        body: HomeDrawer(role: UserRole.yonetici, onModul: rotalar.add),
      )),
    ));
    await tester.pumpAndSettle();

    final sos = find.byKey(const Key('drawer-sos'));
    expect(sos, findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.descendant(of: sos, matching: find.byIcon(Icons.sos_outlined)), findsNothing);
    expect(find.byIcon(Icons.sos_outlined), findsNothing);

    final boyut = tester.getSize(sos);
    expect(boyut.width, greaterThanOrEqualTo(48));
    expect(boyut.height, greaterThanOrEqualTo(48));

    expect(find.bySemanticsLabel('Acil durum'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('SOS')), findsNothing);

    await tester.tap(sos);
    expect(rotalar, ['/panik']);
    handle.dispose();
  });
}
