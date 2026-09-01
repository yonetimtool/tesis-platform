/// (P202) SEMANTIK SURUM KARSILASTIRMASI — sunucudaki `app/surum.py`nin esi.
///
/// ===========================================================================
/// NEDEN ISTEMCIDE DE VAR
/// ===========================================================================
/// Karari SUNUCU verir (bkz. `surum_servisi.dart`). Buradaki karsilastirma
/// kararin KOPYASI DEGIL: uygulamanin kendi surumunu okuyup gonderirken ve
/// erteleme penceresini degerlendirirken surum bilgisini isler. Kural iki
/// tarafta AYNIDIR ve iki tarafta da TEST EDILIR.
///
/// ===========================================================================
/// NEDEN METIN KARSILASTIRMASI DEGIL
/// ===========================================================================
/// "1.10.0".compareTo("1.9.0") NEGATIF doner — yani 1.10.0'i DAHA ESKI
/// sayar. Bu sessiz bir kusurdur: 1.9.0 yayindayken kimse fark etmez,
/// 1.10.0 cikinca zorunlu guncelleme HIC calismaz.
library;

/// "1", "1.2", "1.2.3" — `+yapim` ve `-onsurum` KIRPILIR.
final _bicim = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?$');

/// `"1.10.0"` -> `[1, 10, 0]`. Gecersiz/bos -> `null`.
List<int>? surumAyristir(String? surum) {
  if (surum == null) return null;
  var metin = surum.trim();
  // Yapim numarasi ("1.1.1+6") magazada gorunen surumun parcasi DEGIL.
  for (final ayirac in ['+', '-']) {
    final i = metin.indexOf(ayirac);
    if (i >= 0) metin = metin.substring(0, i);
  }
  metin = metin.trim();
  final e = _bicim.firstMatch(metin);
  if (e == null) return null;
  return [
    int.parse(e.group(1)!),
    int.parse(e.group(2) ?? '0'),
    int.parse(e.group(3) ?? '0'),
  ];
}

/// `a` < `b` ise -1, esitse 0, buyukse 1. Biri gecersizse `null`.
int? surumKarsilastir(String a, String b) {
  final x = surumAyristir(a);
  final y = surumAyristir(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return 0;
}

/// `surum` < `esik` mi.
///
/// BELIRSIZLIKTE KARAR: ENGELLEME. Esik tanimsiz ya da surum okunamaz
/// ise `false` doner. Bu, sunucudaki kararla AYNI ilkedir: zorunlu
/// guncelleme bir guvenlik araci, bir kendini-vurma tetigi degil.
bool surumEskiMi(String? surum, String? esik) {
  final k = surumKarsilastir(surum ?? '', esik ?? '');
  return k != null && k < 0;
}
