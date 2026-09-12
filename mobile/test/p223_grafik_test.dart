/// (P223 §4) MOBIL GRAFIK — uc kural kilitlenir.
///
/// ===========================================================================
/// KILITLENEN KURALLAR
/// ===========================================================================
///  1. RENK TEK BASINA ANLAM TASIMAZ: her cubugun yaninda ADI ve SAYISAL
///     degeri yazar. Renk korlugunde grafik yalnizca suslemedir.
///  2. VERI YOKSA GRAFIK CIZILMEZ: bos bir eksen "sifir" demek yerine
///     bozuk gorunur; yerine acik bir "veri yok" satiri konur.
///  3. RENKLER TEMADAN gelir — KARANLIK TEMADA da okunur. Sabit renk
///     kodlari koyu zeminde kaybolurdu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/grafik/grafik_karti.dart';

import 'helpers/l10n_test_app.dart';

/// TEMA `testTemasi` ILE VERILIR: `l10nApp`in tema parametresi yok,
/// depodaki koyu tema surusu bu global anahtari cevirerek calisiyor
/// (ilk yazimda `temaModu:` adli olmayan bir parametre verdim ve dosya
/// derlenmedi).
Widget _kart(List<GrafikDilimi> dilimler) => l10nApp(
      Scaffold(
        body: GrafikKarti(
          baslik: 'Kategori Kırılımı',
          dilimler: dilimler,
          bicimle: (v) => '${v.round()} TL',
        ),
      ),
    );

void main() {
  testWidgets('SAYI HER CUBUGUN YANINDA yazar (renk tek basina degil)',
      (tester) async {
    await tester.pumpWidget(_kart(const [
      GrafikDilimi(ad: 'Temizlik', deger: 12500),
      GrafikDilimi(ad: 'Güvenlik', deger: 43000),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Temizlik'), findsOneWidget);
    expect(find.text('12500 TL'), findsOneWidget);
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(find.text('43000 TL'), findsOneWidget);
  });

  testWidgets('VERI YOKSA grafik CIZILMEZ, sebep yazilir', (tester) async {
    await tester.pumpWidget(_kart(const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grafik-veri-yok')), findsOneWidget);
  });

  testWidgets('HEPSI SIFIRSA cokmez ve sayilar yine yazilir', (tester) async {
    // Olcek sifir olur; bolme yapilirsa NaN genislik -> cizim hatasi.
    await tester.pumpWidget(_kart(const [
      GrafikDilimi(ad: 'Temizlik', deger: 0),
      GrafikDilimi(ad: 'Güvenlik', deger: 0),
    ]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0 TL'), findsNWidgets(2));
  });

  testWidgets('KARANLIK TEMADA da cizilir ve sayilar okunur', (tester) async {
    testTemasi = ThemeData.dark(useMaterial3: true);
    addTearDown(() => testTemasi = null);
    await tester.pumpWidget(
      _kart(const [GrafikDilimi(ad: 'Asansör', deger: 8200)]),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('8200 TL'), findsOneWidget);
  });
}
