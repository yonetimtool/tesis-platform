/// TUR 48 — CIZIM KATMANINDA SABIT METIN TARAMASI.
///
/// `sozluk_denetimi_test.dart` URETILMIS sozlugu olcer (anahtar kumesi, TR
/// sizintisi, cogul dallari); surusler EKRANI olcer. Ikisinin arasindan
/// gecen bir sey var: kaynakta `l10n` yerine DOGRUDAN yazilmis dizge.
/// Ekranda TR gorunur ama surus o kod yoluna ugramadiysa kimse gormez —
/// tur 47'de panelde tam bu sinif 99 metin cikti.
///
/// Tarama KONUMA bakar: `presentation/` (ve `core/ui/`) altindaki dizge
/// sabitleri. Teknik degerler (dosya uzantisi, MIME, regex, rota, marka,
/// SUNUCU sabitleri) bilerek disaridadir — listesi asagida ve GEREKCELIDIR.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cevrilmesi GEREKMEYEN dizgeler.
///
/// * teknik/bicim: uzanti, MIME, saat kalibi, renk, tek karakter, sayi
/// * `PICCData`: NXP SDM alan ADI (protokol terimi, cevrilmez)
/// * `(Kurulum bekliyor)`: SUNUCUNUN yazdigi yer tutucu DEGER — ekranda
///   gosterilmez, yalnizca "alan hala varsayilan mi" karsilastirmasi icin
///   kullanilir. Cevrilirse karsilastirma bozulur.
/// * marka kilidi (README §15)
/// * `Google` / `Microsoft` / `Apple`: SAGLAYICI MARKA ADLARI (P154 /
///   Asama 4). Cevrilmezler — Almanca arayuzde "Google" yine "Google"dir
///   ve saglayicinin marka kilavuzu da bunu sart kosar. Cevrilen sey
///   onlari saran cumledir (`sosyalIleDevam`), ki o zaten sozlukte.
///
/// * `app.yonetiyor.com`: TESIS YUZEYININ ADRESI. Cevrilecek bir cumle
///   degil bir ADRESTIR ve her dilde AYNI yazilir; cevrilirse denetciye
///   calismayan bir adres verilmis olur (P139.2).
final _izinli = RegExp(
  r'^('
  r'[\d.,:/+\-#%*]+|.{0,1}|[a-z_]+|/[\w/{}.-]*|https?://.*'
  r'|\.(png|jpg|jpeg|webp|heic|heif|svg|pdf)|image/\w+'
  r'|[A-Z_]{2,}|(dd|MM|yyyy|HH|mm|ss)[^A-Za-z]*.*|\#[0-9A-Fa-f]{3,8}'
  r'|\[.*\]|[a-zA-Z0-9]+([-_][a-zA-Z0-9]+)+'
  r'|PICCData|\(Kurulum bekliyor\)|\{\{.*\}\}.*'
  r'|Yönetio|GÜVENLİK & DANIŞMANLIK|app\.yonetiyor\.com'
  r'|Google|Microsoft|Apple'
  r')$',
);

final _harf = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{2}');

/// Satirdaki dizge SABITLERINI ayiklar.
///
/// Regex ile tirnak eslestirmek YANLIS sonuc veriyordu: `ad: '', role: ''`
/// satirinda ikinci ve ucuncu tirnak eslesip `", role: "` diye OLMAYAN bir
/// dizge uretiliyordu. Bu yuzden karakter karakter yurunur; kacis (`\`)
/// ve tirnak turu dogru izlenir.
List<String> _dizgeler(String l) {
  final out = <String>[];
  var i = 0;
  while (i < l.length) {
    final c = l[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final tirnak = c;
    final tampon = StringBuffer();
    i++;
    while (i < l.length) {
      if (l[i] == r'\\') {
        tampon.write(l[i]);
        i += 2;
        continue;
      }
      if (l[i] == tirnak) break;
      tampon.write(l[i]);
      i++;
    }
    i++; // kapanis tirnagi
    out.add(tampon.toString());
  }
  return out;
}

/// Satir sonundaki `//` yorumunu atar (dizge ICINDEKI `//` korunur).
String _yorumsuz(String satir) {
  var tirnak = '';
  for (var i = 0; i < satir.length; i++) {
    final c = satir[i];
    if (tirnak.isEmpty && (c == "'" || c == '"')) {
      tirnak = c;
    } else if (tirnak == c && (i == 0 || satir[i - 1] != r'\')) {
      tirnak = '';
    } else if (tirnak.isEmpty && c == '/' && i + 1 < satir.length && satir[i + 1] == '/') {
      return satir.substring(0, i);
    }
  }
  return satir;
}

void main() {
  test('cizim katmaninda cevrilmemis sabit metin yok', () {
    final bulgular = <String>[];
    for (final e in Directory('lib/src').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (!e.path.contains('/presentation/') && !e.path.contains('/core/ui/')) {
        continue;
      }
      final satirlar = e.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final ham = satirlar[i].trim();
        if (ham.startsWith('import ') ||
            ham.startsWith('export ') ||
            ham.startsWith('//') ||
            ham.startsWith('part ')) {
          continue;
        }
        final l = _yorumsuz(satirlar[i]);
        // Regex ve ENTERPOLASYONLU satirlar atlanir. Enterpolasyon ic ice
        // tirnak icerebilir (`'\${x ? '' : l10n.y}'`) ve hicbir ayiklayici
        // bunu dogru bolemez; ustelik boyle bir satir zaten ifadeden metin
        // uretiyordur. Icindeki olasi sabit parca surusun TR sizinti
        // kilidine takilir (`trSizintisiYok`).
        if (l.contains('RegExp(') || l.contains('\${')) continue;
        for (final t in _dizgeler(l)) {
          // ENTERPOLASYON iceren dizge zaten `l10n`den ya da veriden
          // besleniyor demektir; sabit metin degil.
          if (t.contains(r'$') || t.length < 2 || t.length > 70) continue;
          if (!_harf.hasMatch(t) || _izinli.hasMatch(t)) continue;
          bulgular.add('${e.path}:${i + 1}  "$t"');
        }
      }
    }
    expect(bulgular, isEmpty,
        reason: 'Cevrilmemis sabit metin (context.l10n kullanin):\n'
            '${bulgular.join("\n")}');
  });
}
