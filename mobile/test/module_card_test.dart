import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/module_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ModuleCard — referans "one cikan" kart (chip + baslik + sayac)', () {
    testWidgets('basligi gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const ModuleCard(
        icon: Icons.task_alt,
        title: 'Görevler',
        onTap: null,
      )));
      expect(find.text('Görevler'), findsOneWidget);
    });

    testWidgets('sayac verilince gosterir; verilmeyince sayac yok',
        (tester) async {
      await tester.pumpWidget(_wrap(const ModuleCard(
        icon: Icons.task_alt,
        title: 'Görevler',
        counter: '6 Bekliyor',
      )));
      expect(find.text('6 Bekliyor'), findsOneWidget);

      await tester.pumpWidget(_wrap(const ModuleCard(
        icon: Icons.task_alt,
        title: 'Görevler',
      )));
      expect(find.text('6 Bekliyor'), findsNothing);
    });

    testWidgets('dokununca onTap cagrilir (aktif kart)', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(ModuleCard(
        icon: Icons.task_alt,
        title: 'Görevler',
        onTap: () => tapped++,
      )));
      await tester.tap(find.byType(ModuleCard));
      expect(tapped, 1);
    });

    testWidgets(
        'comingSoon: "Yakında" rozeti gosterir ve dokunma onTap CAGIRMAZ '
        '(MISSING-BACKEND kart)', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(ModuleCard(
        icon: Icons.local_parking,
        title: 'Otopark',
        counter: '78 / 120',
        comingSoon: true,
        onTap: () => tapped++,
      )));
      expect(find.text('Yakında'), findsOneWidget);
      await tester.tap(find.byType(ModuleCard));
      expect(tapped, 0, reason: 'yakinda kart tiklanamaz');
    });

    testWidgets('dense varyant: dar hucrede tasma olmadan cizilir',
        (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 92, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
        height: 128,
        child: ModuleCard(
            icon: Icons.campaign_outlined, title: 'Duyurular', dense: true),
      )));
      expect(find.text('Duyurular'), findsOneWidget);
      expect(tester.takeException(), isNull); // RenderFlex overflow yok
    });
  });
}
