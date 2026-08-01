// (P59) IKINCIL ARAMA DUSTUGUNDE mobil de YANILTMIYOR.
//
// Form seciciler `ref.watch(provider).value ?? const []` ile doluyordu:
// istegin HATASI da "hic kayit yok"a doner ve kullanici acilir listeyi
// bos gorup isini yapamadigini ANLAMAZDI. Panelde ayni sinif P58'de
// kapanmisti.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/eksik_veri_uyarisi.dart';

import 'helpers/l10n_test_app.dart';

void main() {
  testWidgets('hata VARKEN uyari gorunur', (tester) async {
    await tester.pumpWidget(l10nScaffold(const EksikVeriUyarisi(goster: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('yüklenemedi'), findsOneWidget);
  });

  testWidgets('hata YOKKEN hicbir yer kaplamaz', (tester) async {
    await tester.pumpWidget(l10nScaffold(const EksikVeriUyarisi(goster: false)));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('metin CEVRILIR (ingilizce)', (tester) async {
    await tester.pumpWidget(l10nScaffold(
      const EksikVeriUyarisi(goster: true),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });
}
