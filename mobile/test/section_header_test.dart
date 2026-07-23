import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/section_header.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SectionHeader — bolum basligi + "Tümünü Gör" (referans)', () {
    testWidgets('basligi gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Son Hareketler')));
      expect(find.text('Son Hareketler'), findsOneWidget);
    });

    testWidgets('onSeeAll verilince "Tümünü Gör" gorunur ve dokunma cagirir',
        (tester) async {
      var seen = 0;
      await tester.pumpWidget(_wrap(SectionHeader(
        title: 'Vardiya Durumu',
        onSeeAll: () => seen++,
      )));
      expect(find.text('Tümünü Gör'), findsOneWidget);
      await tester.tap(find.text('Tümünü Gör'));
      expect(seen, 1);
    });

    testWidgets('onSeeAll null: "Tümünü Gör" gorunmez ( or. Hızlı Özet)',
        (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Hızlı Özet')));
      expect(find.text('Tümünü Gör'), findsNothing);
    });
  });
}
