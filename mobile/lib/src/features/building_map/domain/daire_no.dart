/// (E2E 2026-09 / TESIS-16 + ANA-4) Tekil daire no ONIZLEMESI.
///
/// Sunucu (`units.daire_no_kanonik`) yalniz rakamdan olusan numarayi toplu
/// olusturmayla ayni bicime getirir: blok "A" + "11" -> "A-11". Form bunu
/// kayittan ONCE gosterir; kural sunucuda, burasi yalniz ayna (baska blok
/// onekli numaranin reddi sunucunun blok listesini bildigi icin orada).
String daireNoOnizle(String no, String? blok) {
  final temiz = no.trim();
  final b = (blok ?? '').trim();
  if (b.isEmpty) return temiz;
  return RegExp(r'^[0-9]+$').hasMatch(temiz) ? '$b-$temiz' : temiz;
}
