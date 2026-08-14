/**
 * (P160) IKI KOORDINAT ARASI MESAFE + ESIK KARARI.
 *
 * =========================================================================
 * ESIK ARTIK VAR — VE BIR AYARDIR
 * =========================================================================
 * Onceki turda burada "sistemde esik YOK, uydurmak urun karari olurdu"
 * yaziyordu. Karar ALINDI (Kerem): varsayilan 50 m, `tenant`ta
 * `okutma_mesafe_esigi_m` olarak tutulur ve Ayarlar'dan degistirilir.
 * Esik SABIT DEGIL cunku site olcekleri cok farkli: bir sitede noktalar
 * 10 m araliklarla, digerinde bloklar arasi 200 m.
 *
 * =========================================================================
 * "BELIRSIZ" UCUNCU BIR SONUCTUR — VE ZORUNLUDUR
 * =========================================================================
 * GPS dogrulugu esikten BUYUKSE karsilastirma KARAR VEREMEZ: ±100 m
 * hatayla olculmus bir mesafenin 50 m esigini gecip gecmedigi
 * bilinemez. Bunu "esik disi" saymak, olcum hatasini ihlal diye
 * raporlamakti — yani birini yanlis suclamak.
 *
 * Bu bir URUN KARARI DEGIL, ARITMETIK: hata payi esigin tamamindan
 * buyukse kiyas anlamsizdir. O yuzden panel ucuncu bir sonuc doner ve
 * mesafeyi yine yazar; yargiyi kullaniciya birakir.
 *
 * Sunucunun kendi gerekcesi de bu yonde (`routers/scans.py`): NTAG424 SDM
 * etiketin FIZIKSEL varligini kriptografik olarak kanitliyor; GPS "konumu
 * ekler", tek basina bir kanit degil.
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

/** Bir okutmanin esige gore durumu. */
export type EsikSonucu = "icinde" | "disinda" | "belirsiz";

/**
 * Mesafeyi esikle karsilastirir.
 *
 * `dogruluk` bilinmiyorsa (eski istemci) karsilastirma yapilir — elde
 * baska bir sey yok ve "belirsiz" demek her okutmayi belirsiz yapardi.
 */
export function esikSonucu(
  mesafe: number,
  esik: number,
  dogruluk: number | null | undefined,
): EsikSonucu {
  if (dogruluk != null && dogruluk > esik) return "belirsiz";
  return mesafe > esik ? "disinda" : "icinde";
}
