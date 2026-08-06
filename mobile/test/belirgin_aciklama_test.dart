// (P141.5) BELIRGIN ACIKLAMA — Play sarti: izin ISTENMEDEN ONCE amac
// ekranda gorunmeli.
//
// EN KRITIK OLCUM: kullanici "Vazgeç" derse `false` doner ve CAGIRAN IZNI
// ISTEMEZ. "Diyalogu goster ama yine de izin iste" davranisi sarti
// karsilamis GORUNUP karsilamaz — bu test o farki olcer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/izin/belirgin_aciklama.dart';

import 'package:mobile/src/core/i18n/locale_controller.dart';

import 'helpers/l10n_test_app.dart';

Future<bool?> _sur(WidgetTester tester, IzinTuru tur, String basilacak) async {
  bool? sonuc;
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: supportedLocales,
    localizationsDelegates: testLocalizationsDelegates,
    home: Builder(
      builder: (c) => Scaffold(
        body: ElevatedButton(
          onPressed: () async => sonuc = await belirginAciklamaGoster(c, tur),
          child: const Text('ac'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(basilacak));
  await tester.pumpAndSettle();
  return sonuc;
}

void main() {
  testWidgets('KONUM: amac ekranda YAZILI (politikaya gomulu degil)',
      (tester) async {
    await _sur(tester, IzinTuru.devriyeKonum, 'Devam');
    // Metin genel gecer degil: NE ICIN ve NE ZAMAN topladigini soyler.
    // (Diyalog kapandi; icerigi acilisken olcmek icin ayri surus asagida.)
  });

  testWidgets('KONUM metni arka plan takibi OLMADIGINI soyler',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: Builder(
        builder: (c) => Scaffold(
          body: ElevatedButton(
            onPressed: () => belirginAciklamaGoster(c, IzinTuru.devriyeKonum),
            child: const Text('ac'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(find.text('Konum izni neden gerekli?'), findsOneWidget);
    expect(
      find.textContaining('arka planda takip etmez'),
      findsOneWidget,
      reason: 'Play: amac ACIK olmali, genel gecer ifade reddedilir',
    );
  });

  testWidgets('VAZGEC -> false: cagiran izni ISTEMEMELI', (tester) async {
    expect(await _sur(tester, IzinTuru.devriyeKonum, 'Vazgeç'), isFalse);
  });

  testWidgets('DEVAM -> true', (tester) async {
    expect(await _sur(tester, IzinTuru.talepFotograf, 'Devam'), isTrue);
  });
}
