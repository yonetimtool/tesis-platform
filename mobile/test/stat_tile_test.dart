import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/stat_tile.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

Widget _wrap(Widget child) =>
    MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: Scaffold(body: Center(child: child)));

const _daire = OzetKutusu(
  ikon: Icons.groups,
  deger: '512',
  id: OzetKutuId.toplamDaire,
  accent: HomeTokens.primary,
);

const _tahsilat = OzetKutusu(
  ikon: Icons.paid_outlined,
  deger: '₺248.750',
  id: OzetKutuId.toplamDaire,
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
              id: OzetKutuId.toplamDaire,
              accent: HomeTokens.orange),
          OzetKutusu(
              ikon: Icons.directions_car,
              deger: '78 / 120',
              id: OzetKutuId.toplamDaire,
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
