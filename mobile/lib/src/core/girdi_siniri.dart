// (P248 §3a) GIRDI UZUNLUK SINIRLARI — sunucuyla AYNI sayilar.
//
// Kaynak: `backend/app/girdi_siniri.py` -> `ISTEMCI_SABITLERI`. Kilit:
// `test/girdi_siniri_test.dart` Python dosyasini okur ve her degerin burada
// AYNI oldugunu olcer (biri degisip oteki unutulursa test kirmizi).
//
// Esleme (Python -> Dart):
//   AD -> ad, BASLIK -> baslik, EPOSTA -> eposta, PAROLA -> parola,
//   GIZLI -> gizli, URL -> url, ADRES -> adres, NOT -> not_,
//   UZUN_NOT -> uzunNot, UZUN_METIN -> uzunMetin, YASAL_METIN -> yasalMetin,
//   KOD -> kod, SLUG -> slug, DOSYA_ADI -> dosyaAdi, ARAMA -> arama,
//   BLOK -> blok, DAIRE_NO -> daireNo, NFC_UID -> nfcUid, IBAN -> iban.
//
// NEDEN ISTEMCIDE DE: kullanici fazlasini YAZAMASIN ("metin alanlarina
// istenildigi kadar yazilabiliyor" sikayeti). ASIL koruma sunucudadir;
// buradaki sinir sunucununkinden BUYUK olamaz. Bir alanin sunucu siniri
// sinif sabitinden farkliysa (ornegin firma adi 150) ekranda sayi +
// `// sunucu: Sema.alan` yorumu kullanilir.
//
// DIKKAT (veri kaybi): Flutter'in uzunluk bicimleyicisi, sinirdan uzun
// MEVCUT bir degeri ilk duzenlemede KIRPAR. Bu yuzden duzenleme ekranlarinda
// sinir sunucununkiyle ESIT tutulur — sunucu zaten daha uzun kaydi kabul
// etmez.
import 'package:flutter/services.dart';

abstract final class GirdiSiniri {
  static const int ad = 100;
  static const int baslik = 200;
  static const int eposta = 254;
  static const int parola = 128;
  static const int gizli = 500;
  static const int url = 2048;
  static const int adres = 500;
  static const int not_ = 2000;
  static const int uzunNot = 5000;
  static const int uzunMetin = 20000;
  static const int yasalMetin = 100000;
  static const int kod = 64;
  static const int slug = 120;
  static const int dosyaAdi = 255;
  static const int arama = 100;
  static const int blok = 32;
  static const int daireNo = 50;
  static const int nfcUid = 64;
  static const int iban = 42;

  // --- YALNIZ ISTEMCI (sunucuda metin degil SAYI; sinir ge/le ile) ---
  /// Para metni: "100.000.000.000,00" (KURUS_UST_SINIR = 10^13 kurus) 18
  /// karakter; ayraclarla birlikte 20 payli.
  static const int tutar = 20;

  /// Tam sayi alani (kat, sira, dakika, port, tuketim...).
  static const int sayi = 12;

  /// Kisa alanlar icin SAYACSIZ sinir (ad, kod, arama, URL...): 100/100
  /// sayaci her kisa alanin altinda gurultudur.
  static List<TextInputFormatter> sinir(int n) =>
      [LengthLimitingTextInputFormatter(n)];
}
