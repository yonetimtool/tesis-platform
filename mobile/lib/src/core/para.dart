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
  final s = input.trim().replaceAll('TL', '').replaceAll('₺', '').replaceAll(' ', '');
  if (s.isEmpty || s.startsWith('-')) return null;

  String tamKisim;
  String ondalik = '';
  if (s.contains(',')) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    tamKisim = parts[0].replaceAll('.', '');
    ondalik = parts[1];
  } else {
    final dot = s.lastIndexOf('.');
    if (dot != -1 && s.length - dot - 1 <= 2 && s.indexOf('.') == dot) {
      tamKisim = s.substring(0, dot);
      ondalik = s.substring(dot + 1);
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
