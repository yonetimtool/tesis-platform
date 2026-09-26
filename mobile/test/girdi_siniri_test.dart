// (P248 §3a) KILIT: mobil girdi sinirlari sunucuyla AYNI.
//
// `backend/app/girdi_siniri.py` icindeki `ISTEMCI_SABITLERI` sozlugu okunur;
// her anahtarin degeri `GirdiSiniri`deki karsiligiyla esit olmali. Sabitler
// once `AD = 100` gibi modul atamalarindan cozulur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/girdi_siniri.dart';

const _dart = <String, int>{
  'AD': GirdiSiniri.ad,
  'BASLIK': GirdiSiniri.baslik,
  'EPOSTA': GirdiSiniri.eposta,
  'PAROLA': GirdiSiniri.parola,
  'GIZLI': GirdiSiniri.gizli,
  'URL': GirdiSiniri.url,
  'ADRES': GirdiSiniri.adres,
  'NOT': GirdiSiniri.not_,
  'UZUN_NOT': GirdiSiniri.uzunNot,
  'UZUN_METIN': GirdiSiniri.uzunMetin,
  'YASAL_METIN': GirdiSiniri.yasalMetin,
  'KOD': GirdiSiniri.kod,
  'SLUG': GirdiSiniri.slug,
  'DOSYA_ADI': GirdiSiniri.dosyaAdi,
  'ARAMA': GirdiSiniri.arama,
  'BLOK': GirdiSiniri.blok,
  'DAIRE_NO': GirdiSiniri.daireNo,
  'NFC_UID': GirdiSiniri.nfcUid,
  'IBAN': GirdiSiniri.iban,
};

void main() {
  test('GirdiSiniri backend ISTEMCI_SABITLERI ile ayni', () {
    final kaynak = File('../backend/app/girdi_siniri.py').readAsStringSync();
    // Modul atamalari: `AD = 100   # ...`, `YASAL_METIN = 100_000`.
    final degerler = <String, int>{};
    for (final m in RegExp(r'^([A-Z_]+)\s*=\s*([0-9_]+)\b', multiLine: true)
        .allMatches(kaynak)) {
      degerler[m.group(1)!] = int.parse(m.group(2)!.replaceAll('_', ''));
    }
    final blok = RegExp(r'ISTEMCI_SABITLERI\s*=\s*\{([^}]*)\}')
        .firstMatch(kaynak)!
        .group(1)!;
    final anahtarlar = RegExp(r'"([A-Z_]+)"\s*:\s*([A-Z_]+)')
        .allMatches(blok)
        .map((m) => MapEntry(m.group(1)!, degerler[m.group(2)!]))
        .toList();
    expect(anahtarlar, isNotEmpty);
    final eksik = <String>[];
    for (final e in anahtarlar) {
      if (!_dart.containsKey(e.key)) {
        eksik.add('${e.key}: Dart karsiligi yok');
      } else if (_dart[e.key] != e.value) {
        eksik.add('${e.key}: backend=${e.value} dart=${_dart[e.key]}');
      }
    }
    expect(eksik, isEmpty, reason: eksik.join('\n'));
    expect(_dart.length, anahtarlar.length,
        reason: 'Dart tarafinda backendde olmayan sabit var');
  });
}
