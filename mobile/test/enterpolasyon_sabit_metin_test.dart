// (P86) ENTERPOLASYONLU DIZGELERDE SABIT METIN.
//
// `sabit_metin_denetimi_test.dart` enterpolasyonlu satirlari BILEREK
// atlar; gerekcesi "enterpolasyon ic ice tirnak icerebilir ve hicbir
// ayiklayici bunu dogru bolemez" idi. P70'te o bolge ilk kez olculdu
// (yedi satir, yedisi de `debugPrint`) ama kilit uc denemede
// dogrulanamadigi icin EKLENMEDI.
//
// Bu dosya o isi AYRI ve KUCUK tutar: mevcut testin suzgeclerine
// dokunmaz, kendi belirtecleyicisini kullanir ve once KENDINI test eder.
// Boylece "kilit calisiyor mu" sorusu, urun kodunu bozmadan yanitlanir —
// P70'te eksik olan tam buydu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bir Dart satirindaki dizge SABITLERININ metnini dondurur;
/// `$ad` ve `${...}` parcalari ATILIR (parantez sayarak).
///
/// Tirnak ve enterpolasyon BIRLIKTE yurutulur: `'${x ? 'a' : 'b'}'`
/// gibi bir satirda enterpolasyonun ICINDEKI tirnaklar dizge acmaz.
List<String> dizgeMetinleri(String satir) {
  final out = <String>[];
  var i = 0;
  while (i < satir.length) {
    final c = satir[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final tirnak = c;
    final buf = StringBuffer();
    i++;
    while (i < satir.length) {
      final ch = satir[i];
      if (ch == r'\') {
        i += 2; // kacis: iki karakter birden atlanir
        continue;
      }
      if (ch == r'$' && i + 1 < satir.length && satir[i + 1] == '{') {
        var derinlik = 0;
        var j = i + 1;
        while (j < satir.length) {
          if (satir[j] == '{') derinlik++;
          if (satir[j] == '}') {
            derinlik--;
            if (derinlik == 0) break;
          }
          j++;
        }
        i = j + 1; // TUM blok atlanir (icindeki tirnaklar dahil)
        continue;
      }
      if (ch == r'$') {
        var j = i + 1;
        while (j < satir.length && RegExp(r'[A-Za-z0-9_]').hasMatch(satir[j])) {
          j++;
        }
        i = j;
        continue;
      }
      if (ch == tirnak) break;
      buf.write(ch);
      i++;
    }
    i++; // kapanis tirnagi
    out.add(buf.toString());
  }
  return out;
}

final _harf = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{3}');

/// Cevrilmesi gereken bir CUMLE parcasi mi? En az uc harfli bir sozcuk
/// VE bir bosluk: `A-12`, `dd.MM.yyyy`, `foo_bar` gibi jetonlar elenir.
bool cevrilmeliMi(String s) {
  final t = s.trim();
  return _harf.hasMatch(t) && t.contains(' ');
}

void main() {
  // --- ONCE KILIDIN KENDISI ---
  group('belirtecleyici dogru boluyor', () {
    test('basit enterpolasyon atilir', () {
      expect(dizgeMetinleri(r"var x = 'Yonetici $n satiri';"),
          ['Yonetici  satiri']);
    });

    test('suslu enterpolasyon TUMUYLE atilir', () {
      expect(dizgeMetinleri(r"Text('Toplam ${a + b} TL')"), ['Toplam  TL']);
    });

    test('enterpolasyon ICINDEKI tirnak dizge ACMAZ', () {
      // P70'te iki YANLIS POZITIF tam buradan cikmisti.
      expect(
        dizgeMetinleri(r"Text('${m.yayin ? '' : l10n.taslak}')"),
        [''],
      );
    });

    test('kacis dizisi tirnagi kapatmaz', () {
      expect(dizgeMetinleri(r"var s = 'a\'b';"), ["ab"]);
    });

    test('cevrilmeliMi: jeton DEGIL cumle arar', () {
      expect(cevrilmeliMi('Yonetici  satiri'), isTrue);
      expect(cevrilmeliMi('A-12'), isFalse);
      expect(cevrilmeliMi('dd.MM.yyyy'), isFalse);
      expect(cevrilmeliMi('gorev_tipi'), isFalse);
    });
  });

  // --- SONRA URUN KODU ---
  test('cizim katmaninda enterpolasyonlu SABIT metin yok', () {
    final bulgular = <String>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (!e.path.contains('/presentation/') && !e.path.contains('/core/ui/')) {
        continue;
      }
      final satirlar = e.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final l = satirlar[i];
        final t = l.trimLeft();
        if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*')) {
          continue;
        }
        // GELISTIRICI GUNLUGU kapsam disi: kullaniciya gorunmez.
        if (l.contains('debugPrint(') || l.contains('assert(')) continue;
        if (!l.contains(r'$')) continue; // enterpolasyonsuz satirlar
        // ...digerini mevcut kilit zaten tariyor.
        for (final metin in dizgeMetinleri(l)) {
          if (cevrilmeliMi(metin)) bulgular.add('${e.path}:${i + 1}  "$metin"');
        }
      }
    }
    expect(bulgular, isEmpty,
        reason: 'Enterpolasyonlu sabit metin (context.l10n kullanin):\n'
            '${bulgular.join("\n")}');
  });
}
