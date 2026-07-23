import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/home/presentation/yonetici_quick_stats.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _ozet = FinancialSummary(
  toplamGelirKurus: 24875000, // 248.750,00 TL
  toplamGiderKurus: 10000000, // 100.000,00
  bakiyeKurus: 14875000, // 148.750,00
  enYuksekGiderler: [],
  tahsilat: TahsilatOzet(
    tahakkukKurus: 30000000,
    tahsilatKurus: 24875000,
    gecikenDaireSayisi: 4,
    tahsilatOraniYuzde: 86,
  ),
);

void main() {
  group('YoneticiQuickStats — "Hızlı Özet" (referans, gercek finans verisi)',
      () {
    testWidgets('baslik + tahsilat/oran/gider/kasa degerleri', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const YoneticiQuickStats(summary: _ozet)));

      expect(find.text('Hızlı Özet'), findsOneWidget);
      expect(find.text('₺248.750,00'), findsNWidgets(2)); // tahsilat + gelir
      expect(find.text('%86'), findsOneWidget);
      expect(find.text('₺148.750,00'), findsOneWidget); // kasa
      expect(find.text('Tahsilat Oranı'), findsOneWidget);
    });

    testWidgets('tahsilat NULL (yetki disi) -> oran kutusu "—" gosterir, '
        'cokme yok', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const ozetsiz = FinancialSummary(
        toplamGelirKurus: 100,
        toplamGiderKurus: 0,
        bakiyeKurus: 100,
        enYuksekGiderler: [],
      );
      await tester.pumpWidget(_wrap(const YoneticiQuickStats(summary: ozetsiz)));
      expect(find.text('—'), findsNWidgets(2)); // tahsilat + oran bilinmiyor
      expect(tester.takeException(), isNull);
    });
  });
}
