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
  });
}
