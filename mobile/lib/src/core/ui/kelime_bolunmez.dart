import 'package:flutter/material.dart';

/// (P239 §1) KELIME ORTASINDAN BOLUNMEYI ONLEYEN PUNTO SECIMI.
///
/// =========================================================================
/// KUSUR VE KOK NEDENI
/// =========================================================================
/// Ana ekran izgarasinda "Görüntüleme İzni" karti metni "Görüntülem / e
/// İzni" diye KELIME ORTASINDAN bolunuyordu. Sebep Flutter'in satir sonu
/// kurali degil, `AutoSizeText`in SECIM OLCUTU: o, metnin TAMAMININ
/// `maxLines` icine sigdigi EN BUYUK puntoyu secer. Bir kelime satira
/// sigmiyorsa Flutter onu ICINDEN boler ve metin yine iki satira "sigmis"
/// olur — yani AutoSizeText'e gore SORUN YOKTUR.
///
/// Olcut yanlis: punto METNIN TAMAMINA degil, EN UZUN KELIMEYE gore
/// secilmeli. Kelime satira sigiyorsa Flutter onu ASLA bolmez.
///
/// =========================================================================
/// KULLANICININ ISTEDIGI SIRA
/// =========================================================================
///  (a) kelime butunlugu korunacak sekilde sar  -> [kartBaslikPuntosu]
///      taban puntodan asagi inerek en uzun kelimenin sigdigi puntoyu bulur
///  (b) sigmiyorsa metni kucult                  -> ayni dongu, [enKucukPunto]e kadar
///  (c) yine sigmiyorsa SONDAN kes + uc nokta    -> `null` doner; cagiran
///      TEK SATIR + ellipsis cizer (iki satira BOLMEZ)
///  (d) tam metin erisilebilirlikte ve ipucunda  -> cagiranin isi
const double kKartBaslikTaban = 14;
const double kKartBaslikEnKucuk = 8;

/// TIRE VE EGIK CIZGI MESRU BOLUNME YERIDIR.
///
/// "Site-Budget" -> "Site-" / "Budget" bir HECE bolunmesi degil; Unicode
/// satir sonu kurali bunu zaten bir firsat sayar ve tipografik olarak
/// dogrudur. Kilit bunlari ihlal saymaz, bu yuzden punto secimi de
/// bunlari kelime siniri kabul eder.
const _bolunebilir = {'-', '/', '‐', '–', '—'};

/// Metni BOLUNMEZ parcalara ayirir: boslukta VE tire/egik cizgiden sonra.
List<String> bolunmezParcalar(String metin) {
  final parcalar = <String>[];
  final tampon = StringBuffer();
  for (final ch in metin.split('')) {
    if (ch.trim().isEmpty) {
      if (tampon.isNotEmpty) parcalar.add(tampon.toString());
      tampon.clear();
      continue;
    }
    tampon.write(ch);
    if (_bolunebilir.contains(ch)) {
      parcalar.add(tampon.toString());
      tampon.clear();
    }
  }
  if (tampon.isNotEmpty) parcalar.add(tampon.toString());
  return parcalar;
}

double _genislik(String s, double punto, TextScaler olcek) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: punto)),
    textDirection: TextDirection.ltr,
    textScaler: olcek,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// En uzun BOLUNMEZ parcanin [enGenislik]e sigdigi en buyuk punto.
///
/// Hicbiri sigmiyorsa `null` — cagiran TEK SATIR + ellipsis cizmeli.
/// Yarim punto adimlariyla inilir: tam punto adimi 320dp'de gorunur bir
/// sicrama uretiyordu (olculdu), daha ince adim gereksiz hesap.
double? kartBaslikPuntosu(
  String metin,
  double enGenislik, {
  double taban = kKartBaslikTaban,
  double enKucuk = kKartBaslikEnKucuk,
  TextScaler olcek = TextScaler.noScaling,
}) {
  final parcalar = bolunmezParcalar(metin);
  if (parcalar.isEmpty) return taban;
  for (var p = taban; p >= enKucuk; p -= 0.5) {
    var hepsiSigdi = true;
    for (final parca in parcalar) {
      if (_genislik(parca, p, olcek) > enGenislik) {
        hepsiSigdi = false;
        break;
      }
    }
    if (hepsiSigdi) return p;
  }
  return null;
}
