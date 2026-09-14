/**
 * (P233 §3) ULKE KODU TABLOSU — telefonun TEK kaynagi (panel ikizi:
 * `mobile/lib/src/core/ui/ulke_telefon.dart`).
 *
 * =========================================================================
 * NEDEN BIR TABLO, NEDEN "+90 SABIT" YETMEDI
 * =========================================================================
 * P123'ten P233'e kadar telefon TR'ye SABITLENMISTI: `telefonNormalle`
 * her numaranin basina kosulsuz `+90` koyuyordu. Yabanci uyruklu bir
 * sakin ya da yurt disindaki bir mal sahibi numarasini girdiginde
 * ekranda hicbir sey ters gorunmuyor, ama saklanan deger BASKA BIR
 * NUMARAYDI — telefon GLOBAL BENZERSIZ anahtar oldugu icin bu, ya
 * baskasinin numarasiyla cakisma ya da erisilemez bir hesap demektir.
 *
 * =========================================================================
 * UZUNLUK SINIRI NEDEN ARALIK (enAz..enCok), TEK SAYI DEGIL
 * =========================================================================
 * Ulkelerin cogunda cep numarasi uzunlugu TEK degildir (IT 9-10, BG 8-9).
 * Maliyet SIMETRIK DEGIL: aralik gereginden GENIS olursa yalnizca bir
 * yazim hatasini yakalayamayiz; gereginden DAR olursa gercek bir insan
 * kaydolamaz. Emin olmadigim yerde aralik GENISLETILDI.
 *
 * =========================================================================
 * LISTE NEDEN BU, NEDEN 240 ULKENIN HEPSI DEGIL
 * =========================================================================
 * Tam ITU listesi icin 240 ulkenin uzunluk araligini UYDURMAM gerekirdi
 * ve uydurulmus DAR bir aralik, yukaridaki asimetriye gore en kotu
 * sonucu verir. Liste: Turkiye + urunun 7 dilinin konusuldugu ulkeler +
 * komsular + sakin/calisan olarak sik gorulen ulkeler. Eksik kalan bir
 * ulke, tabloya TEK SATIR eklenerek gelir.
 *
 * SECENEK ETIKETI = BAYRAK + ISO KODU + ARAMA KODU (`TR +90`).
 * Ulke ADI kullanilmadi: 45 ulke x 7 dil = 315 ceviri borcu, ve ISO kodu
 * ile arama kodu DILDEN BAGIMSIZ okunur. `+1`i paylasan US/CA ile `+7`yi
 * paylasan RU/KZ yalnizca ISO koduyla ayrilir — arama kodu tek basina
 * yeterli olmazdi.
 */

export type Ulke = {
  /** ISO 3166-1 alpha-2. Secimin SAKLANAN degeri degil, listenin anahtari. */
  kod: string;
  /** Arama kodu, `+` HARIC (`"90"`). */
  arama: string;
  /** Ulusal numaranin en az/en cok hane sayisi (ulke kodu HARIC). */
  enAz: number;
  enCok: number;
  /** Ekranda gruplama; verilmezse ucerli parcalanir. */
  gruplar?: number[];
  /** Cep numarasinin baslamasi gereken hane (yalniz TR'de uygulanir). */
  mobilOnEk?: string;
  bayrak: string;
};

/** TR ILK SIRADA: kullanicilarin ezici cogunlugu icin dogru secim. */
export const ULKELER: Ulke[] = [
  { kod: "TR", arama: "90", enAz: 10, enCok: 10, gruplar: [3, 3, 2, 2], mobilOnEk: "5", bayrak: "\u{1F1F9}\u{1F1F7}" },
  { kod: "DE", arama: "49", enAz: 9, enCok: 12, bayrak: "\u{1F1E9}\u{1F1EA}" },
  { kod: "AT", arama: "43", enAz: 9, enCok: 13, bayrak: "\u{1F1E6}\u{1F1F9}" },
  { kod: "CH", arama: "41", enAz: 9, enCok: 9, bayrak: "\u{1F1E8}\u{1F1ED}" },
  { kod: "GB", arama: "44", enAz: 9, enCok: 10, bayrak: "\u{1F1EC}\u{1F1E7}" },
  { kod: "US", arama: "1", enAz: 10, enCok: 10, gruplar: [3, 3, 4], bayrak: "\u{1F1FA}\u{1F1F8}" },
  { kod: "CA", arama: "1", enAz: 10, enCok: 10, gruplar: [3, 3, 4], bayrak: "\u{1F1E8}\u{1F1E6}" },
  { kod: "FR", arama: "33", enAz: 9, enCok: 9, bayrak: "\u{1F1EB}\u{1F1F7}" },
  { kod: "BE", arama: "32", enAz: 8, enCok: 9, bayrak: "\u{1F1E7}\u{1F1EA}" },
  { kod: "NL", arama: "31", enAz: 9, enCok: 9, bayrak: "\u{1F1F3}\u{1F1F1}" },
  { kod: "ES", arama: "34", enAz: 9, enCok: 9, bayrak: "\u{1F1EA}\u{1F1F8}" },
  { kod: "IT", arama: "39", enAz: 9, enCok: 10, bayrak: "\u{1F1EE}\u{1F1F9}" },
  { kod: "PT", arama: "351", enAz: 9, enCok: 9, bayrak: "\u{1F1F5}\u{1F1F9}" },
  { kod: "GR", arama: "30", enAz: 10, enCok: 10, bayrak: "\u{1F1EC}\u{1F1F7}" },
  { kod: "CY", arama: "357", enAz: 8, enCok: 8, bayrak: "\u{1F1E8}\u{1F1FE}" },
  { kod: "BG", arama: "359", enAz: 8, enCok: 9, bayrak: "\u{1F1E7}\u{1F1EC}" },
  { kod: "RO", arama: "40", enAz: 9, enCok: 9, bayrak: "\u{1F1F7}\u{1F1F4}" },
  { kod: "PL", arama: "48", enAz: 9, enCok: 9, bayrak: "\u{1F1F5}\u{1F1F1}" },
  { kod: "SE", arama: "46", enAz: 7, enCok: 10, bayrak: "\u{1F1F8}\u{1F1EA}" },
  { kod: "NO", arama: "47", enAz: 8, enCok: 8, bayrak: "\u{1F1F3}\u{1F1F4}" },
  { kod: "DK", arama: "45", enAz: 8, enCok: 8, bayrak: "\u{1F1E9}\u{1F1F0}" },
  { kod: "RU", arama: "7", enAz: 10, enCok: 10, bayrak: "\u{1F1F7}\u{1F1FA}" },
  { kod: "KZ", arama: "7", enAz: 10, enCok: 10, bayrak: "\u{1F1F0}\u{1F1FF}" },
  { kod: "UA", arama: "380", enAz: 9, enCok: 9, bayrak: "\u{1F1FA}\u{1F1E6}" },
  { kod: "AZ", arama: "994", enAz: 9, enCok: 9, bayrak: "\u{1F1E6}\u{1F1FF}" },
  { kod: "GE", arama: "995", enAz: 9, enCok: 9, bayrak: "\u{1F1EC}\u{1F1EA}" },
  { kod: "SA", arama: "966", enAz: 9, enCok: 9, bayrak: "\u{1F1F8}\u{1F1E6}" },
  { kod: "AE", arama: "971", enAz: 9, enCok: 9, bayrak: "\u{1F1E6}\u{1F1EA}" },
  { kod: "QA", arama: "974", enAz: 8, enCok: 8, bayrak: "\u{1F1F6}\u{1F1E6}" },
  { kod: "KW", arama: "965", enAz: 8, enCok: 8, bayrak: "\u{1F1F0}\u{1F1FC}" },
  { kod: "BH", arama: "973", enAz: 8, enCok: 8, bayrak: "\u{1F1E7}\u{1F1ED}" },
  { kod: "OM", arama: "968", enAz: 8, enCok: 8, bayrak: "\u{1F1F4}\u{1F1F2}" },
  { kod: "IQ", arama: "964", enAz: 10, enCok: 10, bayrak: "\u{1F1EE}\u{1F1F6}" },
  { kod: "IR", arama: "98", enAz: 10, enCok: 10, bayrak: "\u{1F1EE}\u{1F1F7}" },
  { kod: "SY", arama: "963", enAz: 9, enCok: 9, bayrak: "\u{1F1F8}\u{1F1FE}" },
  { kod: "JO", arama: "962", enAz: 9, enCok: 9, bayrak: "\u{1F1EF}\u{1F1F4}" },
  { kod: "LB", arama: "961", enAz: 7, enCok: 8, bayrak: "\u{1F1F1}\u{1F1E7}" },
  { kod: "EG", arama: "20", enAz: 10, enCok: 10, bayrak: "\u{1F1EA}\u{1F1EC}" },
  { kod: "MA", arama: "212", enAz: 9, enCok: 9, bayrak: "\u{1F1F2}\u{1F1E6}" },
  { kod: "DZ", arama: "213", enAz: 9, enCok: 9, bayrak: "\u{1F1E9}\u{1F1FF}" },
  { kod: "TN", arama: "216", enAz: 8, enCok: 8, bayrak: "\u{1F1F9}\u{1F1F3}" },
  { kod: "LY", arama: "218", enAz: 9, enCok: 9, bayrak: "\u{1F1F1}\u{1F1FE}" },
  { kod: "CN", arama: "86", enAz: 11, enCok: 11, bayrak: "\u{1F1E8}\u{1F1F3}" },
  { kod: "IN", arama: "91", enAz: 10, enCok: 10, bayrak: "\u{1F1EE}\u{1F1F3}" },
  { kod: "JP", arama: "81", enAz: 9, enCok: 10, bayrak: "\u{1F1EF}\u{1F1F5}" },
  { kod: "KR", arama: "82", enAz: 9, enCok: 10, bayrak: "\u{1F1F0}\u{1F1F7}" },
  { kod: "AU", arama: "61", enAz: 9, enCok: 9, bayrak: "\u{1F1E6}\u{1F1FA}" },
  { kod: "BR", arama: "55", enAz: 10, enCok: 11, bayrak: "\u{1F1E7}\u{1F1F7}" },
  { kod: "AR", arama: "54", enAz: 10, enCok: 11, bayrak: "\u{1F1E6}\u{1F1F7}" },
  { kod: "MX", arama: "52", enAz: 10, enCok: 10, bayrak: "\u{1F1F2}\u{1F1FD}" },
];

export const VARSAYILAN_ULKE = "TR";

const KODA_GORE = new Map(ULKELER.map((u) => [u.kod, u]));

/** ISO koduna gore ulke; bilinmeyen kod -> `null` (SESSIZCE TR'ye DUSMEZ). */
export function ulkeBul(kod: string | null | undefined): Ulke | null {
  return kod ? (KODA_GORE.get(kod) ?? null) : null;
}

/** Secenek etiketi: `TR +90`. Bayrak ayri cizildigi icin metne girmez. */
export function ulkeEtiketi(u: Ulke): string {
  return `${u.kod} +${u.arama}`;
}

/**
 * E.164 bir degerden ulkeyi cozer.
 *
 * EN UZUN ARAMA KODU ONCE denenir: `+90` ile `+964` ayni `9` ile baslar;
 * kisa kod once denenirse Irak numarasi Turkiye sanilir. Ayni arama
 * kodunu paylasan ulkelerde (US/CA `+1`, RU/KZ `+7`) listedeki ILK ulke
 * doner — SAKLAMA acisindan fark yoktur, yalnizca kutuda gorunen ISO
 * kodu digerine ait olabilir.
 */
export function ulkeyiCoz(e164: string): { ulke: Ulke; ulusal: string } | null {
  const s = (e164 ?? "").replace(/\D/g, "");
  if (!s) return null;
  const siraliKodlar = [...new Set(ULKELER.map((u) => u.arama))].sort(
    (a, b) => b.length - a.length,
  );
  for (const arama of siraliKodlar) {
    if (!s.startsWith(arama)) continue;
    const ulusal = s.slice(arama.length);
    const aday = ULKELER.find((u) => u.arama === arama)!;
    // UZUNLUK DENETIMI: `+7` ile baslayan 10 haneli bir TR numarasi
    // (`7...`) yoktur ama `+90...` bir TR numarasi `9` ile baslar; kod
    // eslesmesi tek basina yeterli degil, kalan hane sayisi da tutmali.
    if (ulusal.length >= aday.enAz && ulusal.length <= aday.enCok) {
      return { ulke: aday, ulusal };
    }
  }
  return null;
}

/** Ulusal haneleri gruplar: `541 922 23 88`. */
export function ulusalBicimle(u: Ulke, haneler: string): string {
  if (!haneler) return "";
  const gruplar = u.gruplar ?? ucerliGruplar(haneler.length);
  const parcalar: string[] = [];
  let i = 0;
  for (const g of gruplar) {
    if (i >= haneler.length) break;
    parcalar.push(haneler.slice(i, Math.min(i + g, haneler.length)));
    i += g;
  }
  if (i < haneler.length) parcalar.push(haneler.slice(i));
  return parcalar.join(" ");
}

/** Gruplama verilmemis ulkeler icin: ucerli, son parca 2-4 hane. */
function ucerliGruplar(n: number): number[] {
  const out: number[] = [];
  let kalan = n;
  while (kalan > 4) {
    out.push(3);
    kalan -= 3;
  }
  if (kalan > 0) out.push(kalan);
  return out;
}
