import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/widgets/zengin_govde.dart';

/// (P171) MOBIL AYNI GOVDEYI GUVENLE CIZIYOR MU.
///
/// =========================================================================
/// BU TEST NE OLCER
/// =========================================================================
/// 1. HAM ETIKET EKRANA SIZMIYOR. Onceki surum `SelectableText(govde)`
///    ciziyordu: sunucu artik `<h2>`/`<li>` iceren govdeler sakladigi icin
///    kullanici yasal metnin ortasinda ham isaretleme goruyordu.
/// 2. METIN KAYBOLMUYOR. "Guvenli ama icerigi yiyen" bir cizici, P170'te
///    odenen bedelin aynisi olurdu.
/// 3. VARLIKLAR COZULUYOR: nh3 metni kacirir (`&amp;`), cozmezsek
///    kullanici ham varlik gorur.
/// 4. TEHLIKELI SEMA ACILMIYOR. Sunucu `javascript:`i zaten reddediyor;
///    buradaki denetim IKINCI KATMAN — bilesen bir gun temizlenmemis bir
///    kaynakla kullanilirsa sessizce tehlikeli bir adres acmasin.
///
/// OLCMEZ: piksel yerlesimi. Olculen sey ICERIK ve GUVENLIK.
Future<void> _ciz(WidgetTester tester, String html) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: ZenginGovde(html)),
    ),
  ));
  await tester.pump();
}

/// Ekranda gorunen tum metni toplar.
String _ekranMetni(WidgetTester tester) {
  final parcalar = <String>[];
  for (final w in tester.widgetList(find.byType(Text))) {
    final t = w as Text;
    parcalar.add(t.data ?? t.textSpan?.toPlainText() ?? '');
  }
  for (final w in tester.widgetList(find.byType(SelectableText))) {
    final t = w as SelectableText;
    parcalar.add(t.data ?? t.textSpan?.toPlainText() ?? '');
  }
  return parcalar.join('\n');
}

void main() {
  testWidgets('HAM ETIKET ekrana sizmaz, metin korunur', (tester) async {
    await _ciz(
      tester,
      '<h2>Aydınlatma</h2><p>Kişisel <strong>verileriniz</strong> işlenir.</p>'
      '<ul><li>Birinci</li><li>İkinci</li></ul>',
    );
    final metin = _ekranMetni(tester);

    expect(metin, contains('Aydınlatma'));
    expect(metin, contains('verileriniz'));
    expect(metin, contains('Birinci'));
    expect(metin, contains('İkinci'));
    // HAM ISARETLEME YOK.
    expect(metin, isNot(contains('<h2>')));
    expect(metin, isNot(contains('<li>')));
    expect(metin, isNot(contains('<strong>')));
  });

  testWidgets('MADDE ISARETI cizilir — liste paragraftan ayirt edilir',
      (tester) async {
    await _ciz(tester, '<ul><li>Bir</li><li>Iki</li></ul>');
    expect(_ekranMetni(tester), contains('•'));
  });

  testWidgets('SIRALI LISTE numaralanir', (tester) async {
    await _ciz(tester, '<ol><li>Bir</li><li>Iki</li></ol>');
    final metin = _ekranMetni(tester);
    expect(metin, contains('1.'));
    expect(metin, contains('2.'));
  });

  testWidgets('VARLIKLAR cozulur (nh3 metni kacirir)', (tester) async {
    await _ciz(tester, '<p>5 &lt; 10 &amp; 3 &gt; 1</p>');
    final metin = _ekranMetni(tester);
    expect(metin, contains('5 < 10 & 3 > 1'));
    expect(metin, isNot(contains('&lt;')));
    expect(metin, isNot(contains('&amp;')));
  });

  testWidgets('`<br>` satir sonu uretir', (tester) async {
    await _ciz(tester, '<p>Ust<br>Alt</p>');
    expect(_ekranMetni(tester), contains('\n'));
  });

  testWidgets('BAGLANTI metni gorunur; TEHLIKELI SEMA tanici ALMAZ',
      (tester) async {
    // Sunucu `javascript:`i zaten reddediyor — bu IKINCI katman.
    await _ciz(
      tester,
      '<p><a href="javascript:alert(1)">Kotu</a> ve '
      '<a href="https://ornek.test">Iyi</a></p>',
    );
    final metin = _ekranMetni(tester);
    expect(metin, contains('Kotu'));
    expect(metin, contains('Iyi'));
    // Adres HICBIR yerde metin olarak gorunmez.
    expect(metin, isNot(contains('javascript:')));

    // Yalniz GUVENLI baglantida dokunma tanicisi var.
    final tanicilar = <String, bool>{};
    void gez(InlineSpan s) {
      if (s is TextSpan) {
        final t = s.toPlainText();
        // BIRIKTIREREK yaz, EZEREK degil: `<a>` span'inin tanicisi
        // vardir ama COCUGUNUN yoktur ve ayni duz metni tasir — ezmek,
        // gercek tanicinin uzerine `false` yazardi.
        if (t == 'Kotu' || t == 'Iyi') {
          tanicilar[t] = (tanicilar[t] ?? false) || s.recognizer != null;
        }
        for (final c in s.children ?? const <InlineSpan>[]) {
          gez(c);
        }
      }
    }

    for (final w in tester.widgetList(find.byType(SelectableText))) {
      final span = (w as SelectableText).textSpan;
      if (span != null) gez(span);
    }
    expect(tanicilar['Kotu'], isNot(true));
    expect(tanicilar['Iyi'], isTrue);
  });

  testWidgets('ESLESMEYEN KAPANIS agaci cokertmez', (tester) async {
    // Sunucu temizledigi icin beklenmez; ama bir cizici, bozuk girdide
    // BOS EKRAN degil ELINDEN GELENI gostermeli.
    await _ciz(tester, '<p>Once</strong> sonra</p></div>');
    expect(_ekranMetni(tester), contains('Once'));
  });

  testWidgets('BOS GOVDE cizim hatasi vermez', (tester) async {
    await _ciz(tester, '');
    expect(tester.takeException(), isNull);
  });
}
