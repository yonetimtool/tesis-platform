// (P250 §1) KİŞİ ADI: AD + SOYAD, Türkçe harf kuralıyla biçim.
//
// Sunucudaki `backend/app/kisi_adi.py` ve web `lib/kisi-adi.ts` ile İKİZ;
// aynı örnekler üç tarafta da testle kilitli (`test/p250_ad_soyad_test.dart`).
//
//   Ad    : her kelimenin baş harfi büyük, gerisi küçük ("mehmet ali" ->
//           "Mehmet Ali"); tire de kelime ayırır.
//   Soyad : tamamı büyük ("yılmaz" -> "YILMAZ").
//
// TÜRKÇE HARF KURALI: Dart'ın `toUpperCase()`u yerel ayar ALMAZ ve "i"yi
// "I" yapar ("ilker" -> "ILKER", yanlış). Dört harf önce elle çevrilir.
//
// YAZARKEN vs KAYDEDERKEN: yazarken yalnız harf büyüklüğü değişir (boşluk
// silinmez, yoksa ikinci ad yazılamaz); kaydederken baş/son kırpılır ve iç
// boşluklar teke iner.
import 'package:flutter/services.dart';

String trBuyuk(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

String trKucuk(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

String _sadelestir(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

final _ayirici = RegExp(r'[\s-]+');

String _kelimeBasi(String s) {
  final sb = StringBuffer();
  var i = 0;
  for (final m in _ayirici.allMatches(s)) {
    sb.write(_kelime(s.substring(i, m.start)));
    sb.write(m.group(0));
    i = m.end;
  }
  sb.write(_kelime(s.substring(i)));
  return sb.toString();
}

String _kelime(String k) =>
    k.isEmpty ? k : trBuyuk(k.substring(0, 1)) + trKucuk(k.substring(1));

String adBicimle(String s, {bool yazarken = false}) =>
    _kelimeBasi(yazarken ? s : _sadelestir(s));

String soyadBicimle(String s, {bool yazarken = false}) =>
    trBuyuk(yazarken ? s : _sadelestir(s));

String tamAd(String ad, String? soyad) =>
    (soyad == null || soyad.isEmpty) ? ad : '$ad $soyad';

/// Saklanan `ad` (TAM ad) + `soyad`tan düzenleme formu ön-dolumu.
/// Soyad bilinmiyorsa (P250 öncesi kayıt) SON KELİME soyad önerilir;
/// kayıt ancak kullanıcı formu kaydedince değişir.
({String ad, String soyad}) adAyir(String tam, String? soyad) {
  if (soyad != null && soyad.isNotEmpty && tam.endsWith(' $soyad')) {
    return (ad: tam.substring(0, tam.length - soyad.length - 1), soyad: soyad);
  }
  final i = tam.lastIndexOf(' ');
  if (i > 0) return (ad: tam.substring(0, i), soyad: tam.substring(i + 1));
  return (ad: tam, soyad: '');
}

/// Yazarken biçim: ad alanı için kelime başı büyük.
class AdBicimlendirici extends TextInputFormatter {
  const AdBicimlendirici();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) =>
      yeni.copyWith(text: adBicimle(yeni.text, yazarken: true));
}

/// Yazarken biçim: soyad alanı için tamamı büyük.
class SoyadBicimlendirici extends TextInputFormatter {
  const SoyadBicimlendirici();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) =>
      yeni.copyWith(text: soyadBicimle(yeni.text, yazarken: true));
}
