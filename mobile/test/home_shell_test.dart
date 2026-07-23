import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_shell.dart';

Widget _shell({
  UserRole role = UserRole.yonetici,
  int unread = 0,
  int currentIndex = 0,
  void Function(int)? onDestinationSelected,
  VoidCallback? onBildir,
  VoidCallback? onProfile,
}) =>
    MaterialApp(
      home: HomeShell(
        role: role,
        unreadCount: unread,
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected ?? (_) {},
        onBildir: onBildir ?? () {},
        onProfile: onProfile,
        body: const Text('GOVDE'),
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

    testWidgets('avatar dokununca onProfile cagrilir', (tester) async {
      var profile = 0;
      await tester.pumpWidget(_shell(onProfile: () => profile++));
      await tester.tap(find.byKey(const Key('home-avatar')));
      expect(profile, 1);
    });
  });
}
