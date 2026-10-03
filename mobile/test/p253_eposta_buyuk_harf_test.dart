/// (P253 acil) E-POSTA BÜYÜK HARF — ekranda REDDEDİLİR, form GÖNDERİLMEZ.
///
/// ÖLÇÜLEN KUSUR (prod): 4 adres büyük harfle başlıyordu; 4 adres harf
/// farkıyla iki kez kayıtlıydı. Klavye cümle başını büyütüyor, alan da
/// kabul ediyordu.
///
/// KARAR: büyük harf yazılınca alan HEMEN "E-posta adresi küçük harfle
/// yazılmalıdır." der, `validate()` false döner (gönderim durur). Klavye
/// otomatik büyük harf YAPMAZ. Sunucu ayrıca küçültür (SSO, Excel).
///
/// P250 SIZINTISI ÖLÇÜLDÜ: ad/soyad biçimleyicisi yalnız `AdSoyadAlanlari`
/// içinde; e-posta alanında `inputFormatters` YOK — aşağıdaki kaynak kilidi
/// bunu kalıcı kılar.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/eposta_alani_widget.dart';

import 'helpers/l10n_test_app.dart';

const _mesaj = 'E-posta adresi küçük harfle yazılmalıdır.';

Future<(GlobalKey<FormState>, TextEditingController)> _ac(WidgetTester t) async {
  final form = GlobalKey<FormState>();
  final ktrl = TextEditingController();
  addTearDown(ktrl.dispose);
  await t.pumpWidget(l10nApp(Scaffold(
    body: Form(
      key: form,
      child: EpostaAlani(
        ktrl: ktrl,
        etiket: 'E-posta',
        alanAnahtari: const Key('e'),
      ),
    ),
  )));
  return (form, ktrl);
}

void main() {
  testWidgets('BUYUK HARF: alan ANINDA hata verir, validate() false', (t) async {
    final (form, _) = await _ac(t);
    await t.enterText(find.byKey(const Key('e')), 'Frknkymkc1996@gmail.com');
    await t.pump();
    // Odak hâlâ alanda (blur YOK) — hata yine görünür.
    expect(find.text(_mesaj), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
  });

  testWidgets('KUCUK HARF: hata yok, validate() true, deger DEGISMEZ', (t) async {
    final (form, ktrl) = await _ac(t);
    await t.enterText(find.byKey(const Key('e')), 'frknkymkc1996@gmail.com');
    await t.pump();
    expect(find.text(_mesaj), findsNothing);
    expect(form.currentState!.validate(), isTrue);
    expect(ktrl.text, 'frknkymkc1996@gmail.com');
  });

  testWidgets('KLAVYE: otomatik buyuk harf, oto-duzeltme ve oneri KAPALI', (t) async {
    await _ac(t);
    final alan = t.widget<TextField>(find.descendant(
        of: find.byKey(const Key('e')), matching: find.byType(TextField)));
    expect(alan.textCapitalization, TextCapitalization.none);
    expect(alan.autocorrect, isFalse);
    expect(alan.enableSuggestions, isFalse);
    expect(alan.keyboardType, TextInputType.emailAddress);
    // P250: e-posta alanina hicbir bicimleyici takili degil.
    expect(alan.inputFormatters ?? const [], isEmpty);
  });

  test('KAYNAK KILIDI: EpostaAlani kullanan her ekran gonderimde kurali okur', () {
    // `validate()` (Form) ya da `epostaHataMetni(` (Form'suz govde kuran
    // ekran, ornek: defter formu). Ikisi de yoksa alan hata gosterir ama
    // istek yine gider.
    final eksik = <String>[];
    for (final f in Directory('lib/src/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (!s.contains('EpostaAlani(')) continue;
      if (!s.contains('.validate()') && !s.contains('epostaHataMetni(')) eksik.add(f.path);
    }
    expect(eksik, isEmpty);
  });

  test('KAYNAK KILIDI: ad/soyad bicimleyicisi e-posta degerine UYGULANMAZ (P250)', () {
    final ihlal = <String>[];
    final desen = RegExp(r'(adBicimle|soyadBicimle)\([^)]*(eposta|email)', caseSensitive: false);
    for (final f in Directory('lib/src').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final satirlar = f.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        if (desen.hasMatch(satirlar[i])) ihlal.add('${f.path}:${i + 1}');
      }
    }
    expect(ihlal, isEmpty);
  });
}
