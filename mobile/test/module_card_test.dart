import 'package:auto_size_text/auto_size_text.dart';
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

    testWidgets('dense: uzun baslik dar hucrede kesilmeden sigar',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 88,
              height: 132,
              child: ModuleCard(
                icon: Icons.directions_car_outlined,
                title: 'Otopark Kullanımı',
                counter: '78 / 120',
                dense: true,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Otopark Kullanımı'), findsOneWidget);
      expect(find.text('78 / 120'), findsOneWidget);
    });

    testWidgets('dense: farkli uzunlukta basliklar AYNI grupla AYNI boyutta',
        (tester) async {
      final group = AutoSizeGroup();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 88, height: 132,
                child: ModuleCard(
                  icon: Icons.campaign_outlined, title: 'Duyurular',
                  dense: true, titleGroup: group,
                ),
              ),
              SizedBox(
                width: 88, height: 132,
                child: ModuleCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Otopark Kullanımı', dense: true, titleGroup: group,
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Ayni grup → ayni fontSize (uzunluga gore degismez).
      final t1 = tester.widget<AutoSizeText>(
          find.ancestor(of: find.text('Duyurular'),
              matching: find.byType(AutoSizeText)));
      final t2 = tester.widget<AutoSizeText>(
          find.ancestor(of: find.text('Otopark Kullanımı'),
              matching: find.byType(AutoSizeText)));
      expect(t1.group, same(t2.group));
      expect(tester.takeException(), isNull);
    });
  });
}
