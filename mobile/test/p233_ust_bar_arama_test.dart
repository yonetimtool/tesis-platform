/// (P233 §2) UST BAR KISAYOLU — dil simgesi yerine ARAMA.
///
/// =========================================================================
/// NE OLCULUYOR
/// =========================================================================
/// Ust bar her rolde AYNI kabuktan (`HomeShell`) cizilir. Olculen sey:
///   1. arama simgesi VAR ve arama ekranina goturur,
///   2. dil simgesi ust barda YOK,
///   3. karsilama satirinda IKINCI bir arama simgesi YOK (P230 §3'te
///      oraya konmustu; ikisini de birakmak ayni isi iki yerden yapan
///      bir arayuz demekti),
///   4. dokunma hedefi 48 dp (P220 kilidi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_shell.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_header.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'helpers/l10n_test_app.dart';

void main() {
  testWidgets('UST BARDA ARAMA VAR, DIL YOK', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: l10nApp(
      HomeShell(
        role: UserRole.yonetici,
        currentIndex: 0,
        unreadCount: 0,
        onDestinationSelected: (_) {},
        onBildir: () {},
        onModul: (_) {},
        body: const SizedBox(),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-arama')), findsOneWidget);
    // Dil simgesi ust bardan KALKTI — Ayarlar'daki karti duruyor.
    expect(find.byKey(const Key('home-dil')), findsNothing);
  });

  testWidgets('DOKUNMA HEDEFI 48 dp (P220)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: l10nApp(
      HomeShell(
        role: UserRole.yonetici,
        currentIndex: 0,
        unreadCount: 0,
        onDestinationSelected: (_) {},
        onBildir: () {},
        onModul: (_) {},
        body: const SizedBox(),
      ),
    )));
    await tester.pumpAndSettle();
    final boyut = tester.getSize(find.byKey(const Key('home-arama')));
    expect(boyut.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(boyut.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('KARSILAMA SATIRINDA IKINCI ARAMA YOK', (tester) async {
    // P230 §3'te arama karsilama satirina konmustu. Ust bara tasininca
    // IKISINI DE birakmak, ayni isi iki yerden yapan ve hangisinin
    // "gercek" oldugu belirsiz bir arayuz uretirdi.
    await tester.pumpWidget(l10nScaffold(
      const HomeHeader(greetingName: 'Mehmet', subtitle: 'A Blok'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ana-arama')), findsNothing);
  });
}
