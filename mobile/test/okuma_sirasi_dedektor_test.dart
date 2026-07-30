/// TUR 60 — OKUMA SIRASI DEDEKTORUNUN KENDI TESTI.
///
/// Tur 59'un dersi: ilk kosumda temiz donen bir surus, olctugunu KANITLAMADAN
/// "temiz" sayilamaz. Burada dort sey kanitlanir:
///  1. Gezinme sirasi GERCEKTEN okunuyor (etiketler dogru sirada gelir).
///  2. `sortKey` ile BOZULMUS bir sira yakalanir (dikey geri atlama).
///  3. Ayni bantta YON bozulmasi yakalanir (LTR'de saga-sola atlama).
///  4. RTL'de kural TERSINE cevrilir: Arapca'da sagdan sola okumak IHLAL
///     DEGILDIR — yoksa surus butun RTL ekranlarda yanlis alarm verirdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

/// Uc satir, dogru sirada.
Widget _duzgun(String dil) => MaterialApp(
  home: Directionality(
    textDirection: dil == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    child: const Scaffold(
      body: Column(children: [Text('bir'), Text('iki'), Text('uc')]),
    ),
  ),
);

/// Ayni gorsel yerlesim, ama `sortKey` gezinme sirasini TERSINE cevirir.
/// Ekran GORSEL olarak kusursuz; yalniz ekran okuyucu yanlis okur.
Widget _bozukSira(String dil) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        Semantics(sortKey: const OrdinalSortKey(3), child: const Text('bir')),
        Semantics(sortKey: const OrdinalSortKey(2), child: const Text('iki')),
        Semantics(sortKey: const OrdinalSortKey(1), child: const Text('uc')),
      ],
    ),
  ),
);

/// Ayni SATIRDA yon bozulmasi: sagdaki oge soldakinden ONCE okunur.
Widget _bozukYon(String dil) => MaterialApp(
  home: Scaffold(
    body: Row(
      children: [
        Semantics(sortKey: const OrdinalSortKey(2), child: const Text('solda')),
        Semantics(sortKey: const OrdinalSortKey(1), child: const Text('sagda')),
      ],
    ),
  ),
);

void main() {
  testWidgets('DEDEKTOR 1: gezinme sirasi okunuyor (etiketler sirali)', (
    tester,
  ) async {
    final tutamak = tester.ensureSemantics();
    await tester.pumpWidget(_duzgun('tr'));
    await tester.pumpAndSettle();
    final dizi = gezinmeSirasi(tester);
    expect(
      dizi.map((d) => d.etiket),
      containsAllInOrder(['bir', 'iki', 'uc']),
      reason: 'okunan: ${dizi.join(" | ")}',
    );
    expect(okumaSirasiIhlalleri(dizi), isEmpty);
    tutamak.dispose();
  });

  testWidgets('DEDEKTOR 2: sortKey ile TERS cevrilmis sira YAKALANIR', (
    tester,
  ) async {
    final tutamak = tester.ensureSemantics();
    await tester.pumpWidget(_bozukSira('tr'));
    await tester.pumpAndSettle();
    final dizi = gezinmeSirasi(tester);
    // Once bozulmanin GERCEKTEN olustugunu dogrula (yoksa test bos kosar).
    expect(
      dizi.map((d) => d.etiket).toList(),
      ['uc', 'iki', 'bir'],
      reason: 'sortKey uygulanmadi: ${dizi.join(" | ")}',
    );
    final ihlal = okumaSirasiIhlalleri(dizi);
    expect(ihlal, hasLength(2), reason: ihlal.join('\n'));
    expect(ihlal.first, contains('DIKEY GERI'));
    tutamak.dispose();
  });

  testWidgets('DEDEKTOR 3: ayni bantta YON bozulmasi YAKALANIR', (
    tester,
  ) async {
    final tutamak = tester.ensureSemantics();
    await tester.pumpWidget(_bozukYon('tr'));
    await tester.pumpAndSettle();
    final dizi = gezinmeSirasi(tester);
    expect(dizi.map((d) => d.etiket).toList(), ['sagda', 'solda']);
    final ihlal = okumaSirasiIhlalleri(dizi);
    expect(ihlal, hasLength(1), reason: ihlal.join('\n'));
    expect(ihlal.single, contains('YATAY GERI (ltr)'));
    tutamak.dispose();
  });

  testWidgets('DEDEKTOR 4: RTL kurali TERS — sagdan sola okumak ihlal degil', (
    tester,
  ) async {
    // ONEMLI: burada GERCEK yerelleştirilmiş uygulama (`l10nApp`) kullanilir.
    // Ciplak bir `Directionality` YETMEZ: Flutter gezinme sirasini siralarken
    // SEMANTIK agactaki `textDirection`a bakar; onu `Localizations`/`MaterialApp`
    // zinciri saglar. Ciplak `Directionality` ile semantik agac yonsuz kalir ve
    // Flutter LTR'ye gore siralar — yani sentetik bir kurguyla yapilan RTL
    // olcumu URUNU DEGIL kurguyu olcer. (Bu ayrimi dedektoru yazarken kacirdim;
    // once yanlis alarm verdi.)
    final tutamak = tester.ensureSemantics();
    await tester.pumpWidget(
      l10nApp(
        Scaffold(
          body: Column(
            children: [
              Row(children: const [Text('bas'), Spacer(), Text('son')]),
              const Text('alt satir'),
            ],
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    final dizi = gezinmeSirasi(tester);
    // Arapca'da satir SAGDAN baslar: 'bas' saga yerlesir ve ONCE okunur.
    expect(dizi.map((d) => d.etiket).toList(), [
      'bas',
      'son',
      'alt satir',
    ], reason: 'okunan: ${dizi.join(" | ")}');
    expect(
      okumaSirasiIhlalleri(dizi, rtl: true),
      isEmpty,
      reason: 'RTL kurali yanlis alarm verdi: ${dizi.join(" | ")}',
    );
    // Ayni dizi LTR kuraliyla denetlenirse IHLAL cikar — kural gercekten yone
    // duyarli, sabit degil.
    expect(okumaSirasiIhlalleri(dizi, rtl: false), isNotEmpty);
    tutamak.dispose();
  });
}
