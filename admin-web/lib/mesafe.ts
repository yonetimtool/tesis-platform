/**
 * (P160) IKI KOORDINAT ARASI MESAFE — metre.
 *
 * =========================================================================
 * BU BIR OLCUMDUR, BIR YARGI DEGIL
 * =========================================================================
 * Okutma haritasi "bu okutma noktadan N metre uzakta yapilmis" diyor ve
 * ORADA DURUYOR. "Supheli", "uzak", "kural disi" DEMIYOR — cunku sistemde
 * boyle bir esik YOK ve uydurmak bir URUN KARARI olurdu.
 *
 * Sunucunun kendi gerekcesi de bu yonde (`routers/scans.py`): NTAG424 SDM
 * etiketin FIZIKSEL varligini kriptografik olarak kanitliyor; GPS "konumu
 * ekler", tek basina bir kanit degil. Yani mesafeyi alarma cevirmek,
 * sunucunun kurmadigi bir kurali panelde icat etmekti.
 *
 * MESAFE YANINDA DOGRULUK DA YAZILIR: ±50 m dogrulukla olculmus 30 m'lik
 * bir sapma HICBIR SEY soylemez. Ikisini birlikte gostermek, sayiyi
 * yanlis okumayi engelleyen tek yol.
 *
 * =========================================================================
 * HAVERSINE — neden bu
 * =========================================================================
 * Site olceginde (yuzlerce metre) duzlemsel yaklasim da yeterdi, ama
 * haversine hem kisa hem dogru ve enlem arttikca bozulmuyor. Dunya
 * yaricapi ortalama kure yaricapi (WGS84 ortalama).
 */

/** Ortalama Dunya yaricapi (m) — WGS84 ortalama kure. */
const DUNYA_YARICAPI = 6_371_008.8;

const derece = (d: number) => (d * Math.PI) / 180;

/** Iki nokta arasi buyuk cember mesafesi — METRE, tam sayiya yuvarli. */
export function mesafeMetre(
  aLat: number,
  aLon: number,
  bLat: number,
  bLon: number,
): number {
  const dLat = derece(bLat - aLat);
  const dLon = derece(bLon - aLon);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(derece(aLat)) * Math.cos(derece(bLat)) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * DUNYA_YARICAPI * Math.asin(Math.min(1, Math.sqrt(h))));
}
