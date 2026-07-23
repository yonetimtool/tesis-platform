import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/activity_row.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ActivityRow — "Son Hareketler" satiri (referans)', () {
    testWidgets('baslik + alt-satir + saat gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const ActivityRow(
        icon: Icons.report_gmailerrorred,
        title: 'Kamera İhlal Tespiti',
        subtitle: 'Otopark Girişi - Kamera 3',
        time: '09:32',
      )));
      expect(find.text('Kamera İhlal Tespiti'), findsOneWidget);
      expect(find.text('Otopark Girişi - Kamera 3'), findsOneWidget);
      expect(find.text('09:32'), findsOneWidget);
    });

    testWidgets('dokununca onTap cagrilir', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(ActivityRow(
        icon: Icons.local_shipping,
        title: 'Kargo Teslim Alındı',
        subtitle: 'Mng Kargo - 245781236',
        time: '09:05',
        onTap: () => tapped++,
      )));
      await tester.tap(find.byType(ActivityRow));
      expect(tapped, 1);
    });
  });
}
