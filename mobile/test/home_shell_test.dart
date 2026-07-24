import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_shell.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';

Widget _shell({
  UserRole role = UserRole.yonetici,
  int unread = 0,
  int currentIndex = 0,
  void Function(int)? onDestinationSelected,
  void Function(String)? onModul,
  VoidCallback? onBildir,
  VoidCallback? onProfile,
  VoidCallback? onLogout,
}) =>
    ProviderScope(
      // App-bar avatari [myAvatarUrlProvider] izler — testte aga cikmasin.
      overrides: [myAvatarUrlProvider.overrideWith((ref) async => null)],
      child: MaterialApp(
        home: HomeShell(
          role: role,
          unreadCount: unread,
          currentIndex: currentIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onModul: onModul ?? (_) {},
          onBildir: onBildir ?? () {},
          onProfile: onProfile,
          onLogout: onLogout,
          body: const Text('GOVDE'),
        ),
      ),
    );

void main() {
  group('HomeShell — app-bar + govde + 5 yuvali alt-bar (referans)', () {
    testWidgets('govdeyi ve 5 yuva etiketini gosterir', (tester) async {
      await tester.pumpWidget(_shell());
      expect(find.text('GOVDE'), findsOneWidget);
      for (final label in [
        'Ana Sayfa',
        'Bildirimler',
        'Olay Bildir',
        'Raporlar',
        'Ayarlar',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('marka kilidi: kelime isareti + harf arali alt-baslik',
        (tester) async {
      await tester.pumpWidget(_shell());
      expect(find.text('Yönetio'), findsOneWidget);
      expect(find.text('GÜVENLİK & DANIŞMANLIK'), findsOneWidget);
    });

    testWidgets('resident merkez FAB "Talep / Bildir" (homeBildirLabel)',
        (tester) async {
      await tester.pumpWidget(_shell(role: UserRole.resident));
      expect(find.text('Talep / Bildir'), findsOneWidget);
    });

    testWidgets('merkez FAB dokununca onBildir cagrilir', (tester) async {
      var bildir = 0;
      await tester.pumpWidget(_shell(onBildir: () => bildir++));
      await tester.tap(find.byKey(const Key('home-fab')));
      expect(bildir, 1);
    });

    testWidgets('merkez FAB 56px daire (referans olcusu)', (tester) async {
      await tester.pumpWidget(_shell());
      final daire = tester.getSize(find.descendant(
        of: find.byKey(const Key('home-fab')),
        matching: find.byType(Container),
      ));
      expect(daire.width, HomeTokens.fabSize);
      expect(daire.height, HomeTokens.fabSize);
    });

    testWidgets('aktif yuva DOLGU ikon + mavi; pasif yuva ince ikon',
        (tester) async {
      await tester.pumpWidget(_shell(currentIndex: 0));
      final aktif = tester.widget<Icon>(find.byIcon(Icons.home));
      expect(aktif.color, HomeTokens.primary);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget); // pasif
      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('"Raporlar" destinasyonu dokununca onDestinationSelected(3)',
        (tester) async {
      int? selected;
      await tester.pumpWidget(_shell(onDestinationSelected: (i) => selected = i));
      await tester.tap(find.text('Raporlar'));
      expect(selected, 3);
    });

    testWidgets(
        'okunmamis > 0: sayi HEM app-bar zilinde HEM Bildirimler sekmesinde '
        '(referans ikisini de rozetler); 0 iken hic sayi yok', (tester) async {
      await tester.pumpWidget(_shell(unread: 3));
      expect(find.text('3'), findsNWidgets(2));

      await tester.pumpWidget(_shell(unread: 0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('avatar dokununca hesap menusu acilir: Profil -> onProfile, '
        'Çıkış Yap -> onLogout (logout her rolde erisilir)', (tester) async {
      var profile = 0;
      var logout = 0;
      await tester.pumpWidget(_shell(
        onProfile: () => profile++,
        onLogout: () => logout++,
      ));

      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(profile, 1);

      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkış Yap'));
      await tester.pumpAndSettle();
      expect(logout, 1);
    });

    testWidgets('hamburger cekmecesi rolun TUM modullerini listeler; secim '
        'rotayi geri verir (referans izgaradan cikan moduller kaybolmaz)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? rota;
      await tester.pumpWidget(_shell(
        role: UserRole.security,
        onModul: (r) => rota = r,
      ));

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      // Referans hizli erisim seridinde OLMAYAN moduller cekmecede duruyor.
      expect(find.text('Turlarım'), findsOneWidget);
      expect(find.text('Görevlerim'), findsOneWidget);
      expect(find.text('Demirbaş'), findsOneWidget);

      await tester.tap(find.text('Demirbaş'));
      await tester.pumpAndSettle();
      expect(rota, '/assets');
    });
  });
}
