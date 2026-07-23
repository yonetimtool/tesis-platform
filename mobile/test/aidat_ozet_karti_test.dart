import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/presentation/aidat_ozet_karti.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('AidatOzetKarti — "Ödeme ve Aidat Durumu" (site-sakini.jpeg)', () {
    testWidgets('borcsuz: yesil "Borç Yok" cipi + daire no', (tester) async {
      await tester.pumpWidget(_wrap(AidatOzetKarti(
        units: const [
          MyDuesUnit(
              unitId: 'u1',
              no: '12',
              tahakkukKurus: 125000,
              odenenKurus: 125000,
              bakiyeKurus: 0),
        ],
        onDetay: () {},
      )));

      expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
      expect(find.text('Borç Yok'), findsOneWidget);
      expect(find.textContaining('Daire 12'), findsOneWidget);
    });

    testWidgets('borclu: kirmizi toplam borc TL + "Geçmiş Ödemeler" dokunusu '
        'onDetay cagirir', (tester) async {
      var detay = 0;
      await tester.pumpWidget(_wrap(AidatOzetKarti(
        units: const [
          MyDuesUnit(
              unitId: 'u1',
              no: '12',
              tahakkukKurus: 250000,
              odenenKurus: 125000,
              bakiyeKurus: 125000),
          MyDuesUnit(
              unitId: 'u2',
              no: '14',
              tahakkukKurus: 100000,
              odenenKurus: 100000,
              bakiyeKurus: 0),
        ],
        onDetay: () => detay++,
      )));

      // Toplam borc TUM dairelerin bakiyesi: 1.250,00 TL.
      expect(find.text('₺1.250,00'), findsOneWidget);
      expect(find.text('Borç Yok'), findsNothing);
      await tester.tap(find.text('Geçmiş Ödemeler'));
      expect(detay, 1);
    });

    testWidgets('bos daire listesi: kart HIC cizilmez', (tester) async {
      await tester.pumpWidget(_wrap(AidatOzetKarti(
        units: const [],
        onDetay: () {},
      )));
      expect(find.text('Ödeme ve Aidat Durumu'), findsNothing);
    });
  });
}
