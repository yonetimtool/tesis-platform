import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/stat_tile.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('StatTile — "Hızlı Özet" istatistik blogu (referans)', () {
    testWidgets('deger + etiket gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const StatTile(
        icon: Icons.groups_outlined,
        value: '512',
        label: 'Toplam Daire',
      )));
      expect(find.text('512'), findsOneWidget);
      expect(find.text('Toplam Daire'), findsOneWidget);
    });

    testWidgets('alt-etiket verilince gorunur; verilmeyince gorunmez',
        (tester) async {
      await tester.pumpWidget(_wrap(const StatTile(
        icon: Icons.percent,
        value: '%86',
        label: 'Aidat Tahsilat Oranı',
        sublabel: 'Bu Ay',
      )));
      expect(find.text('Bu Ay'), findsOneWidget);

      await tester.pumpWidget(_wrap(const StatTile(
        icon: Icons.percent,
        value: '%86',
        label: 'Aidat Tahsilat Oranı',
      )));
      expect(find.text('Bu Ay'), findsNothing);
    });

    testWidgets('dense varyant: dar hucrede tasma olmadan cizilir',
        (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 92, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
        height: 148,
        child: StatTile(
          icon: Icons.payments_outlined,
          value: '₺248.750,00',
          label: 'Toplam Tahsilat',
          sublabel: 'Bu Ay',
          dense: true,
        ),
      )));
      expect(find.text('₺248.750,00'), findsOneWidget);
      expect(tester.takeException(), isNull); // RenderFlex overflow yok
    });

    testWidgets('dense=false varsayilani: eski gorunum (2 satir etiket) korunur',
        (tester) async {
      await tester.pumpWidget(_wrap(const StatTile(
        icon: Icons.groups_outlined,
        value: '512',
        label: 'Toplam Daire',
      )));
      final label = tester.widget<Text>(find.text('Toplam Daire'));
      expect(label.maxLines, 2);
    });

    testWidgets('dense: uzun para degeri dar hucrede tasmadan sigar',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 88, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
              height: 150,
              child: StatTile(
                icon: Icons.payments_outlined,
                value: '₺248.750',
                label: 'Toplam Tahsilat',
                sublabel: 'Bu Ay',
                dense: true,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull); // RenderFlex overflow yok
      expect(find.text('₺248.750'), findsOneWidget); // deger hala ekranda
      // Deger ellipsis ile KESILMEZ, FittedBox ile kuculerek sigar.
      expect(
        find.ancestor(
            of: find.text('₺248.750'), matching: find.byType(FittedBox)),
        findsOneWidget,
      );
    });
  });
}
