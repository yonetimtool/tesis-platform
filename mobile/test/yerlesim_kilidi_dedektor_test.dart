/// TUR 60 — YERLESIM KILIDININ KENDI TESTI.
///
/// Kilit dosyalari uretildi ve ikinci kosumda gecti. Bu KANIT DEGIL: hicbir
/// seyi olcmeyen bir dokum de her kosumda ayni cikar ve "gecer". Burada uc sey
/// kanitlanir:
///  1. Dokum KARARLI: ayni ekran iki kez cizilince ayni cikar (yoksa kilit
///     her kosumda yanlis alarm verirdi).
///  2. Dokum DUYARLI: 8 px'lik bir dolgu degisikligi dokumu degistirir.
///  3. Dokum SIRALI ve TEKIL: `allRenderObjects` ayni `RenderParagraph`i
///     birkac kez verir; tekillestirme yapilmazsa satirlar tekrarlanir
///     (ilk surumde tam bunu yasadi — her yazi alti kez yaziliyordu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ekran_surus.dart';

Widget _ekran({double dolgu = 0}) => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.only(top: dolgu),
      child: const Column(
        children: [
          Text('birinci satir'),
          Text('ikinci satir'),
          Text('ucuncu satir'),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('DEDEKTOR 1: dokum KARARLI (ayni ekran -> ayni dokum)', (
    tester,
  ) async {
    await tester.pumpWidget(_ekran());
    await tester.pumpAndSettle();
    final bir = yerlesimDokumu(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_ekran());
    await tester.pumpAndSettle();
    expect(yerlesimDokumu(tester), bir);
  });

  testWidgets('DEDEKTOR 2: dokum DUYARLI (8 px dolgu farki gorulur)', (
    tester,
  ) async {
    await tester.pumpWidget(_ekran());
    await tester.pumpAndSettle();
    final once = yerlesimDokumu(tester);
    await tester.pumpWidget(_ekran(dolgu: 8));
    await tester.pumpAndSettle();
    final sonra = yerlesimDokumu(tester);
    expect(
      sonra,
      isNot(once),
      reason: 'dolgu degisti ama dokum ayni kaldi — kilit KOR',
    );
    // Ve fark gercekten KONUMDA: satir sayisi ayni, y degerleri 8 kaymis.
    expect(sonra, hasLength(once.length));
    expect(
      sonra.first.trimLeft().startsWith('8,'),
      isTrue,
      reason: 'ilk satir: ${sonra.first}',
    );
  });

  testWidgets('DEDEKTOR 3: her yazi BIR kez, y sirasinda', (tester) async {
    await tester.pumpWidget(_ekran());
    await tester.pumpAndSettle();
    final dokum = yerlesimDokumu(tester);
    expect(dokum, hasLength(3), reason: dokum.join('\n'));
    expect(dokum[0], contains('birinci satir'));
    expect(dokum[1], contains('ikinci satir'));
    expect(dokum[2], contains('ucuncu satir'));
  });
}
