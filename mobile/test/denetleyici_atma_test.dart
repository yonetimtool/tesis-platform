// (P110) OLUSTURULAN HER DENETLEYICI ATILIR — sinif kilidi.
//
// `TextEditingController` bir dinleyici listesi ve yerel metin durumu
// tasir; atilmazsa yasar. Sinif alanlari `dispose()`ta atiliyordu ama
// DIYALOG ACAN metotlarin ICINDE uretilen yerel denetleyiciler
// atilmiyordu (P109 olcumu: 106'dan 3'u). `flutter analyze` bunu GORMEZ —
// lint yerel degiskenleri izlemez, yani kusur sessizdir.
//
// P109'da naif duzeltme (await sonrasi dispose) COKTU: diyalogun cikis
// animasyonu hala `TextField`i ciziyor. Dogru cozum SAHIPLIK: denetleyici
// diyalogun kendi durumuna ait olur (`metin_iste_diyalogu.dart`) ve
// `State.dispose` animasyon bitince cagrilir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// (P110) TIP YAZILMIS BILDIRIMLERI DE YAKALAR.
///
/// Ilk surum `final (\w+) = TextEditingController(` bekliyordu ve
/// `late final TextEditingController _ctrl = TextEditingController(...)`
/// bicimini HIC gormuyordu — yani kilidin kendi ornek dosyasi kapsam
/// disindaydi. Enjeksiyonla olculdu: `_ctrl.dispose()` silindiginde test
/// GECIYORDU. Tip artik istege bagli bir gruptur ve ad her iki bicimde de
/// dogru yakalanir.
///
/// BOSLUK `;` GECEMEZ: ilk denemede `[\s\S]{0,60}?` kullanildi ve
/// `final _formKey = GlobalKey<FormState>();` bildirimini bir alt
/// satirdaki `TextEditingController(` ile eslestirip BES yanlis pozitif
/// uretti. Ayirici artik `[^;]` — bir bildirim digerine tasamaz.
final _olusturma = RegExp(
  r'(?:late\s+)?final\s+'
  r'(?:(?:TextEditingController|ScrollController|FocusNode)\s+)?'
  r'(\w+)\s*=\s*[^;]{0,60}?'
  r'(?:TextEditingController|ScrollController|FocusNode)\(',
);

void main() {
  test('olusturulan her denetleyici bir yerde dispose ediliyor', () {
    final eksik = <String>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final s = e.readAsStringSync();
      for (final m in _olusturma.allMatches(s)) {
        final ad = m.group(1)!;
        // Nerede atildigina bakilmaz: sinif alani `dispose()` icinde,
        // diyalog denetleyicisi ise kendi `State.dispose`unda atilir.
        // Iki dogru bicim de bu kontrolu gecer; yanlis olan HIC atmamaktir.
        if (!s.contains('$ad.dispose()')) eksik.add('${e.path}: $ad');
      }
    }
    expect(eksik, isEmpty,
        reason: 'Atilmayan denetleyici (sizinti):\n${eksik.join("\n")}');
  });
}
