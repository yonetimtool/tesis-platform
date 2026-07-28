/// TUR 32 — DETEKTORUN KENDISINI SINA.
///
/// Koyu tema surusu `textContrastGuideline` uzerine kuruludur: gecen bir
/// surus ancak kilavuz GERCEKTEN olcuyorsa bir sey soyler. Onceki turlarda
/// tam bu sinif hata cikti — tarayici yanlis ALARM veriyordu (tur 25/30);
/// buradaki risk tersi: kilavuz sessizce hicbir seyi olcmuyor olabilir ve
/// "7 dilde koyu temada temiz" raporu bos cikardi.
///
/// Bu yuzden bilerek KOTU bir ekran cizilir (koyu zeminde koyu yazi) ve
/// kilavuzun DUSTUGU dogrulanir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/app_theme.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

void main() {
  testWidgets('DETEKTOR: dusuk kontrast kilavuzu DUSURUR', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(
          backgroundColor: Color(0xFF1B1B1F),
          body: Center(
            child: Text('okunmaz', style: TextStyle(color: Color(0xFF232327))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Object? hata;
    try {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } catch (e) {
      hata = e;
    }
    expect(hata, isNotNull,
        reason: 'kontrast kilavuzu koyu-uzerine-koyu metni KACIRDI — '
            'koyu tema surusu bos kosuyor demektir');
  });

  testWidgets('DETEKTOR: yeterli kontrast kilavuzu GECIRIR', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(
          backgroundColor: Color(0xFF1B1B1F),
          body: Center(
            child: Text('okunur', style: TextStyle(color: Color(0xFFE6E1E5))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('DETEKTOR: surus temayi GERCEKTEN koyuya alir', (tester) async {
    // `testTemasi` anahtari kurulmadan `l10nApp` ACIK temadadir; surus
    // yardimcisi onu koyuya cevirir. Anahtar calismazsa tum tur 32 sessizce
    // acik temayi olcerdi.
    await tester.pumpWidget(l10nApp(const Scaffold(body: Text('x'))));
    expect(Theme.of(tester.element(find.byType(Material).first)).brightness,
        Brightness.light);

    await koyuTemaSurusu(tester, (dil) => l10nApp(
          const Scaffold(body: Text('x')),
          locale: Locale(dil),
        ));
  });
}
