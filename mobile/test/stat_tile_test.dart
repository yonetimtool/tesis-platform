import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/stat_tile.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

const _daire = OzetKutusu(
  ikon: Icons.groups,
  deger: '512',
  etiket: 'Toplam Daire',
  altEtiket: 'Tüm Site',
  accent: HomeTokens.primary,
);

const _tahsilat = OzetKutusu(
  ikon: Icons.paid_outlined,
  deger: '₺248.750',
  etiket: 'Toplam Tahsilat',
  altEtiket: 'Bu Ay',
  accent: HomeTokens.green,
);

void main() {
  group('StatTile — "Hızlı Özet" istatistik kutusu (referans)', () {
    testWidgets('deger + etiket + alt-etiket gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const StatTile(kutu: _daire)));
      expect(find.text('512'), findsOneWidget);
      expect(find.text('Toplam Daire'), findsOneWidget);
      expect(find.text('Tüm Site'), findsOneWidget);
    });

    testWidgets('dar hucre (4 sutunlu izgara): uzun para degeri tasmadan sigar',
        (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 88, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
        height: 130,
        child: StatTile(kutu: _tahsilat, hucreGenisligi: 88),
      )));
      expect(find.text('₺248.750'), findsOneWidget);
      expect(tester.takeException(), isNull); // RenderFlex overflow yok
    });
  });

  group('HizliOzetIzgarasi — 4 kutu (referans yonetici.jpeg)', () {
    testWidgets('4 kutuyu da cizer, tasma yok', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const SizedBox(
        width: 368,
        child: HizliOzetIzgarasi(kutular: [
          _daire,
          _tahsilat,
          OzetKutusu(
              ikon: Icons.percent,
              deger: '%86',
              etiket: 'Aidat Tahsilat Oranı',
              altEtiket: 'Bu Ay',
              accent: HomeTokens.orange),
          OzetKutusu(
              ikon: Icons.directions_car,
              deger: '78 / 120',
              etiket: 'Otopark Doluluk',
              altEtiket: '%65',
              accent: HomeTokens.purple),
        ]),
      )));

      expect(find.text('512'), findsOneWidget);
      expect(find.text('₺248.750'), findsOneWidget);
      expect(find.text('%86'), findsOneWidget);
      expect(find.text('78 / 120'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bos liste: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(_wrap(const HizliOzetIzgarasi(kutular: [])));
      expect(find.byType(StatTile), findsNothing);
    });
  });
}
