/// Para ayristirma CEKIRDEGI (P49) — tek kaynak.
///
/// NEDEN AYRI DOSYA: `parseTlToKurus` butce modelinin icindeydi ve butceye
/// ozel bir POLITIKA tasiyordu (`kurus > 0` degilse null). Bagimsiz bolum
/// tanimlarinda ise **0 = MUAF** gecerli ve anlamli bir degerdir; o ekran
/// bu yuzden kendi naif ayristiricisini yazmisti ve o kopya Turkce binlik
/// ayiricisini (`1.250,00`) ANLAMIYORDU — yani uygulama kendi gosterdigi
/// bicimi reddediyordu.
///
/// Cozum: AYRISTIRMA burada (politikasiz), POLITIKA cagirana ait.
library;

/// "1.250,00" / "1250,00" / "1250.00" / "1250" -> 125000 (kurus).
///
/// AYIRICI KURALI (Turkce yazim):
///   * Virgul VARSA: virgul ONDALIK, nokta BINLIK ayiricidir.
///   * Virgul YOKSA ve TEK bir nokta varsa ve ondan sonra en fazla iki
///     hane varsa: nokta ONDALIK (sayisal klavyeden gelen `1250.00`).
///   * Aksi halde nokta BINLIK ayiricidir (`1.250` = 1250).
///
/// Isaret/sifir POLITIKASI YOKTUR: negatif metin null doner (isaret bir
/// bicim degil, alan kuralidir), ama 0 GECERLIDIR — "muaf" ile "tanimsiz"
/// ayrimini cagiran yapar.
int? tlMetniniKurusaCevir(String input) {
  // (P50) Para birimi jetonu ve UC BOSLUKLARI temizlenir; ICERIDEKI bosluk
  // BIRAKILIR ve reddedilir: `1 000` Turkce yazimda bir sayi DEGILDIR ve
  // icerideki bosluklari silmek `1 2 3`u de kabul etmek olurdu. Panel de
  // AYNI kurali uygular.
  final s = input.replaceAll('TL', '').replaceAll('₺', '').trim();
  if (s.isEmpty || s.startsWith('-') || RegExp(r'\s').hasMatch(s)) return null;

  String tamKisim;
  String ondalik = '';
  if (s.contains(',')) {
    final parts = s.split(',');
    // (P50) ONDALIK AYIRICI VARSA ARDINDA HANE OLMALI: `750,` YARIM bir
    // giristir ve sessizce 750,00 saymak, kullanicinin yazmayi bitirmedigi
    // bir tutari kaydetmek olurdu. Panel de AYNI kurali uygular — iki
    // istemcinin ayni metni farkli ayristirmasi, ayni sitede farkli tutar
    // girilebilmesi demekti.
    // Ayiricinin ONUNDE de hane olmali: `,50` yine YARIM bir giristir.
    if (parts.length != 2 || parts[1].isEmpty || parts[0].isEmpty) {
      return null;
    }
    tamKisim = parts[0].replaceAll('.', '');
    ondalik = parts[1];
  } else {
    final dot = s.lastIndexOf('.');
    if (dot != -1 &&
        s.length - dot - 1 >= 1 &&
        s.length - dot - 1 <= 2 &&
        s.indexOf('.') == dot) {
      if (dot == 0) return null; // `.50` — yarim giris
      tamKisim = s.substring(0, dot);
      ondalik = s.substring(dot + 1);
    } else if (dot == s.length - 1) {
      return null; // `750.` — yarim giris
    } else {
      tamKisim = s.replaceAll('.', '');
    }
  }

  if (ondalik.length > 2) return null;
  if (tamKisim.isEmpty && ondalik.isEmpty) return null;
  final tam = int.tryParse(tamKisim.isEmpty ? '0' : tamKisim);
  final kurusPart =
      ondalik.isEmpty ? 0 : int.tryParse(ondalik.padRight(2, '0'));
  if (tam == null || kurusPart == null) return null;
  return tam * 100 + kurusPart;
}
