/// (P233 §3) TELEFON ALANI WIDGET'I — ülke kodu SEÇİLİR, elle yazılmaz.
///
/// Saf fonksiyonlar `telefon_bicimlendirici_test.dart`ta ölçülüyor. Burada
/// ölçülen şey ZİNCİR: seçiciye dokunulunca denetleyicideki HAM DEĞER
/// gerçekten değişiyor mu, ve o değer sunucuya gidecek E.164'ü üretiyor mu.
/// P226/P229 dersi: aradaki halka ölçülmezse iki ucu doğru olan bir zincir
/// yine kopuk kalabilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/ui/telefon_alani.dart';
import 'package:mobile/src/core/ui/telefon_alani_widget.dart';

Widget _sar(TextEditingController k, {bool zorunlu = false}) => MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TelefonAlani(
          ktrl: k,
          etiket: 'Telefon',
          zorunlu: zorunlu,
          alanAnahtari: const Key('tel-numara'),
          ulkeAnahtari: const Key('tel-ulke'),
        ),
      ),
    );

void main() {
  testWidgets('ULKE KUTUSU BOS BASLAR (sessiz +90 YOK)', (t) async {
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));

    // Kutuda hicbir ulke secili degil.
    // Kutuda hicbir ulke secili degil: yer tutucu goruluyor.
    expect(find.text('Seçin'), findsOneWidget);

    // Numara yazilir ama ULKE SECILMEDIGI icin sunucuya gidecek deger BOS
    // — eski davranis burada sessizce `+90` ekliyordu.
    await t.enterText(find.byKey(const Key('tel-numara')), '5419222388');
    await t.pump();
    expect(telefonNormalle(k.text), '');
    expect(telefonHatasi(k.text), TelefonHatasi.ulkeYok);
  });

  testWidgets('ULKE SECILINCE KOD DOLAR ve E.164 uretilir', (t) async {
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));
    await t.enterText(find.byKey(const Key('tel-numara')), '5419222388');
    await t.pump();

    await t.tap(find.byKey(const Key('tel-ulke')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('telefon-ulke-TR')));
    await t.pumpAndSettle();

    expect(k.text, '(+90) 541 922 23 88');
    expect(telefonNormalle(k.text), '+905419222388');
    expect(telefonHatasi(k.text), isNull);
  });

  testWidgets('MEVCUT KAYITTA ulke DEGERDEN cozulur', (t) async {
    final k = TextEditingController(text: '+491711234567');
    await t.pumpWidget(_sar(k));
    expect(find.text('\u{1F1E9}\u{1F1EA} DE +49'), findsOneWidget);
    expect(find.text('171 123 4567'), findsOneWidget);
  });

  testWidgets('UZUNLUK SINIRI ULKEYE GORE — fazla rakam GIRILEMEZ', (t) async {
    final k = TextEditingController(text: '+974');
    await t.pumpWidget(_sar(k));
    // Katar: 8 hane. 10 rakam yazilir, 8'i girer.
    await t.enterText(find.byKey(const Key('tel-numara')), '3312345678');
    await t.pump();
    expect(k.text, '(+974) 331 234 56'); // QA 8 hane -> 3-3-2
    expect(telefonNormalle(k.text), '+97433123456');
  });

  testWidgets('ULKE DEGISINCE fazla haneler KIRPILIR', (t) async {
    final k = TextEditingController(text: '+905419222388');
    await t.pumpWidget(_sar(k));

    await t.tap(find.byKey(const Key('tel-ulke')));
    await t.pumpAndSettle();
    // ARAMA kutusu: elli ulkede kaydirmak yerine yazip bulmak.
    await t.enterText(find.byKey(const Key('telefon-ulke-ara')), 'QA');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('telefon-ulke-QA')));
    await t.pumpAndSettle();

    // 10 hane -> 8 hane. Sessizce birakmak, KAYDEDILEMEYEN bir numarayi
    // gecerli gostermek olurdu.
    expect(telefonNormalle(k.text), '+97454192223');
  });

  testWidgets('YAPISTIRILAN ULKE KODU seciciyi GUNCELLER', (t) async {
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));
    // Rehberden kopyalanan numara: kullanicidan ayrica Almanya'yi secmesi
    // BEKLENMEZ — bilgi zaten metnin icinde.
    await t.enterText(find.byKey(const Key('tel-numara')), '+49 171 1234567');
    await t.pump();
    expect(telefonNormalle(k.text), '+491711234567');
  });
}
