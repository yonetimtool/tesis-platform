// (P212 §2) FOTOGRAF YOKSA BAS HARFLER — genel bir "kisi" ikonu DEGIL.
//
// ===========================================================================
// NEDEN
// ===========================================================================
// Web'de bu KARAR ZATEN VERILMISTI (`admin-web/components/Avatar.tsx`):
// avatar bir susleme degil, HANGI HESAPLA girildiginin gostergesidir.
// Mobil ise fotograf yokken herkese ayni gri silueti ciziyordu; iki
// hesabi olan (yonetici + sakin, ya da iki tesis) kullanici icin o fark
// siliniyordu. Ayrica "fotografi kaldirdim, ne oldu?" sorusunun cevabi
// da budur: ad baslar gorunur, bos bir ikon degil.
//
// Kurallar WEB ILE AYNI (iki yuzey ayrismasin):
//   * en fazla IKI harf; tek kelimelik adda ILK IKI harf ("Ku"),
//   * `toUpperCase` TURKCE'ye gore: `i` -> `İ` degil `I` olmamali —
//     Dart'ta `toUpperCase()` locale-duyarsizdir ve "Ilker"i dogru
//     buyutur ama "istanbul" -> "ISTANBUL" verir; Turkce'de dogrusu
//     "İSTANBUL"dur. Bu yuzden `i` ELDE cevrilir.
//   * renk ADDAN turetilir (rastgele DEGIL): ayni kisi her acilista ayni
//     rengi alir, yoksa "hesap degisti mi?" sorusu her yenilemede
//     yeniden sorulurdu.
library;

import 'package:flutter/material.dart';

/// Adin bas harfleri — en fazla iki harf. Bos ad -> bos dize.
String basHarfler(String ad) {
  final parcalar =
      ad.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parcalar.isEmpty) return '';
  final ham = parcalar.length == 1
      ? (parcalar[0].length >= 2
          ? parcalar[0].substring(0, 2)
          : parcalar[0])
      : '${parcalar.first[0]}${parcalar.last[0]}';
  return _trBuyut(ham);
}

/// Turkce buyutme: `i` -> `İ`, `ı` -> `I`. Dart'in `toUpperCase()`i
/// locale tanimaz ve `i`yi `I` yapar — "İsmail" -> "IS" cikardi.
String _trBuyut(String s) => s
    .replaceAll('i', 'İ')
    .replaceAll('ı', 'I')
    .toUpperCase();

/// Addan KARARLI ton (0-359) — web'deki `tonu()` ile ayni toplama.
int adTonu(String ad) {
  var toplam = 0;
  for (final r in ad.runes) {
    toplam = (toplam + r) % 360;
  }
  return toplam;
}

/// Fotograf varsa fotograf, yoksa bas harfler.
class BasHarfAvatar extends StatelessWidget {
  const BasHarfAvatar({
    super.key,
    required this.ad,
    this.url,
    this.cap = 64,
    this.gorsel,
  });

  final String ad;
  final String? url;
  final double cap;

  /// Testlerde ag istegi yapilmasin diye gecersiz kilinabilir.
  final ImageProvider? gorsel;

  @override
  Widget build(BuildContext context) {
    final harfler = basHarfler(ad);
    final ton = adTonu(ad);
    final zemin = HSLColor.fromAHSL(1, ton.toDouble(), 0.45, 0.82).toColor();
    final yazi = HSLColor.fromAHSL(1, ton.toDouble(), 0.60, 0.24).toColor();
    final resim = url != null ? (gorsel ?? NetworkImage(url!)) : null;
    return CircleAvatar(
      radius: cap / 2,
      backgroundColor: zemin,
      backgroundImage: resim,
      child: resim != null
          ? null
          : harfler.isEmpty
              // Ad da yoksa (beklenmez) ikon: bos bir daire, "yukleniyor"
              // ile karistirilirdi.
              ? Icon(Icons.person_outline, size: cap * 0.5, color: yazi)
              : Text(
                  harfler,
                  style: TextStyle(
                    fontSize: cap * 0.4,
                    fontWeight: FontWeight.w600,
                    color: yazi,
                  ),
                ),
    );
  }
}
