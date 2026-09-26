// (P248 §3a) KAYNAK TARAMA KILIDI — sinirsiz metin girdisi YOK.
//
// Kullanici: "metin alanlarina istenildigi kadar yazilabiliyor". lib/
// altindaki her `TextField(` / `TextFormField(` / `CupertinoTextField(`
// cagrisi parantez eslenerek ayristirilir; argumanlarinda sinir yoksa test
// KIRMIZI. Sinir sayilanlar:
//   * `maxLength:` (uzun metinde sayac gorunur),
//   * `LengthLimitingTextInputFormatter(`,
//   * `GirdiSiniri.sinir(` (sayacsiz kisa alan yardimcisi).
// Degerin SUNUCU siniriyla uyumu ekranda `GirdiSiniri` sabiti ya da
// `// sunucu: Sema.alan` yorumuyla belgelenir; sabitlerin kendisi
// `girdi_siniri_test.dart` ile backend'e kilitli.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bilincli istisnalar: dosya (lib/ goreli) -> gerekce.
const _istisnalar = <String, String>{
  'src/core/ui/telefon_alani_widget.dart':
      'TELEFON alanlari P248 §2 ortak bileseninde (ulke kodu + ulusal numara '
          'kurali); uzunluk orada numara kuralina gore uygulanir.',
};

final _cagri = RegExp(r'\b(TextField|TextFormField|CupertinoTextField)\(');

int _kapanis(String s, int ac) {
  var derin = 0;
  String? tirnak;
  for (var i = ac; i < s.length; i++) {
    final c = s[i];
    if (tirnak != null) {
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == tirnak) tirnak = null;
    } else if (c == "'" || c == '"') {
      tirnak = c;
    } else if (c == '(') {
      derin++;
    } else if (c == ')') {
      derin--;
      if (derin == 0) return i;
    }
  }
  return s.length - 1;
}

bool _sinirli(String arg) =>
    arg.contains('maxLength:') ||
    arg.contains('LengthLimitingTextInputFormatter(') ||
    arg.contains('GirdiSiniri.sinir(');

/// Kaynak metindeki sinirsiz cagrilarin satir numaralari.
List<int> sinirsizCagrilar(String kaynak) {
  final out = <int>[];
  for (final m in _cagri.allMatches(kaynak)) {
    final ac = m.end - 1;
    final arg = kaynak.substring(ac, _kapanis(kaynak, ac) + 1);
    if (!_sinirli(arg)) {
      out.add('\n'.allMatches(kaynak.substring(0, m.start)).length + 1);
    }
  }
  return out;
}

void main() {
  test('lib/ altinda sinirsiz metin girdisi yok', () {
    final kok = Directory('lib');
    final ihlal = <String>[];
    var sayi = 0;
    for (final f in kok.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final goreli = f.path.substring('lib/'.length);
      final kaynak = f.readAsStringSync();
      sayi += _cagri.allMatches(kaynak).length;
      if (_istisnalar.containsKey(goreli)) continue;
      for (final s in sinirsizCagrilar(kaynak)) {
        ihlal.add('$goreli:$s');
      }
    }
    expect(sayi, greaterThan(100), reason: 'tarama bir sey bulmadi — bozuk');
    expect(ihlal, isEmpty,
        reason: 'maxLength / GirdiSiniri.sinir olmayan metin girdileri:\n'
            '${ihlal.join('\n')}');
  });

  test('istisna dosyalari hala var', () {
    for (final d in _istisnalar.keys) {
      expect(File('lib/$d').existsSync(), isTrue, reason: d);
    }
  });

  test('tarayici sinirsiz cagriyi yakalar (sahte kaynak)', () {
    const kaynak = '''
Widget a() => TextField(controller: c, decoration: InputDecoration(labelText: f(x)));
Widget b() => TextField(controller: c, maxLength: 10);
Widget d() => TextFormField(inputFormatters: GirdiSiniri.sinir(GirdiSiniri.ad));
''';
    expect(sinirsizCagrilar(kaynak), [1]);
  });
}
