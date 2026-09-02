/**
 * (P206 §3) IBAN — normalize, DOGRULA (mod 97), bicimle, BANKAYI COZ.
 *
 * =========================================================================
 * SUNUCUNUN AYNISI, VE BU BILINCLI BIR KOPYA
 * =========================================================================
 * Kural `backend/app/iban.py`de de var. Ikisi de gerekli:
 *   * SUNUCU son sozu soyler (istemci her zaman bizim istemcimiz degil),
 *   * ISTEMCI kullaniciyi 422 beklemeden uyarir ve YAZARKEN gruplar.
 * Ayrisma riski `tests/p206-iban.test.ts`te AYNI ornek kumesiyle iki
 * tarafta da olculuyor.
 *
 * =========================================================================
 * ULKE SINIRI YOK — GEREKCE
 * =========================================================================
 * Eski denetim `^TR[0-9]{24}$` idi: yurt disindaki bir tesis kendi
 * IBAN'ini giremiyor, buna karsilik tek hanesi yanlis yazilmis bir TR
 * IBAN'i kabul ediliyordu. Uzunluk ULKEYE gore denetlenir (biliniyorsa),
 * dogruluk MOD 97 ile.
 */

/** ISO 13616 uzunluklari — sik kullanilanlar (liste TAM DEGIL). */
export const IBAN_UZUNLUK: Record<string, number> = {
  AT: 20, BE: 16, BG: 22, CH: 21, CY: 28, CZ: 24, DE: 22, DK: 18, EE: 20,
  ES: 24, FI: 18, FR: 27, GB: 22, GR: 27, HR: 21, HU: 28, IE: 22, IT: 27,
  LT: 20, LU: 20, LV: 21, MT: 31, NL: 18, NO: 15, PL: 28, PT: 25, RO: 24,
  RS: 22, SE: 24, SI: 19, SK: 24, TR: 26, UA: 29, AE: 23, SA: 24, QA: 29,
  KW: 30, BH: 22, AZ: 28, GE: 22, MD: 24, MK: 19, ME: 22, BA: 20, AL: 28,
  IS: 26, LI: 21, MC: 27, SM: 27,
};

export const IBAN_ASGARI = 15;
export const IBAN_AZAMI = 34;

/** Bosluk/tire at, buyuk harfe cevir — KANONIK bicim. */
export function ibanTemizle(ham: string | null | undefined): string {
  return (ham ?? "").replace(/[\s-]/g, "").toUpperCase();
}

/** Dorderli gruplar: `TR33 0006 1005 ...`. Insan gozu 26 haneyi tek
 *  blokta karsilastiramaz. */
export function ibanBicimle(ham: string | null | undefined): string {
  const t = ibanTemizle(ham);
  return (t.match(/.{1,4}/g) ?? []).join(" ");
}

/** Yazarken kullanilan giris bicimi: gruplar + AZAMI uzunluk SERT sinir.
 *  Sinirsiz yazdirip sonra reddetmek, kullaniciyi bosuna ugrastirirdi. */
export function ibanGiris(ham: string): string {
  return ibanBicimle(ibanTemizle(ham).slice(0, IBAN_AZAMI));
}

function mod97(iban: string): number {
  const tasinmis = iban.slice(4) + iban.slice(0, 4);
  // PARCA PARCA: 34 haneli IBAN `Number` tasar. Ayni yontem sunucuda da
  // yazili — iki tarafin ayrisma riskini yontem farki uretirdi.
  let kalan = 0;
  for (const ch of tasinmis) {
    const sayi = /[A-Z]/.test(ch) ? String(ch.charCodeAt(0) - 55) : ch;
    for (const b of sayi) kalan = (kalan * 10 + Number(b)) % 97;
  }
  return kalan;
}

export type IbanHatasi =
  | "iban_bos"
  | "iban_bicim"
  | "iban_uzunluk"
  | "iban_saglama";

/** Gecersizse HATA KIMLIGI, gecerliyse `null`. Metin cagirinin isi
 *  (sozlukten cevrilir). */
export function ibanHatasi(ham: string | null | undefined): IbanHatasi | null {
  const iban = ibanTemizle(ham);
  if (!iban) return "iban_bos";
  if (!/^[A-Z]{2}[0-9]{2}[A-Z0-9]+$/.test(iban)) return "iban_bicim";
  if (iban.length < IBAN_ASGARI || iban.length > IBAN_AZAMI) return "iban_uzunluk";
  const beklenen = IBAN_UZUNLUK[iban.slice(0, 2)];
  if (beklenen !== undefined && iban.length !== beklenen) return "iban_uzunluk";
  if (mod97(iban) !== 1) return "iban_saglama";
  return null;
}

/**
 * (P206 §3.2) TR banka kodlari (EFT). LISTE KAPALI DEGIL: burada olmayan
 * banka icin SERBEST GIRIS korunur — katilim bankalari, yeni lisans
 * alanlar ve yabanci subeler bu listeyi her zaman geride birakir ve
 * kapali liste GERCEK bir hesabi kaydedilemez yapardi.
 */
export const TR_BANKALAR: Record<string, string> = {
  "0001": "T.C. Merkez Bankası",
  "0010": "Ziraat Bankası",
  "0012": "Halkbank",
  "0015": "Vakıfbank",
  "0032": "Türk Ekonomi Bankası (TEB)",
  "0046": "Akbank",
  "0059": "Şekerbank",
  "0062": "Garanti BBVA",
  "0064": "Türkiye İş Bankası",
  "0066": "Türkiye İş Bankası",
  "0067": "Yapı Kredi",
  "0092": "Citibank",
  "0099": "ING Bank",
  "0103": "Fibabanka",
  "0108": "Turkland Bank",
  "0111": "QNB Finansbank",
  "0123": "HSBC",
  "0124": "Alternatifbank",
  "0125": "Burgan Bank",
  "0134": "Denizbank",
  "0135": "Anadolubank",
  "0138": "Deutsche Bank",
  "0143": "Aktif Yatırım Bankası",
  "0146": "Odeabank",
  "0203": "Albaraka Türk",
  "0205": "Kuveyt Türk",
  "0206": "Türkiye Finans",
  "0209": "Ziraat Katılım",
  "0210": "Vakıf Katılım",
  "0211": "Emlak Katılım",
  "0800": "PTT Bank",
};

/** Acilir listede gosterilecek sirali banka adlari (tekrarsiz). */
export const BANKA_ADLARI: string[] = Array.from(
  new Set(Object.values(TR_BANKALAR)),
).sort((a, b) => a.localeCompare(b, "tr"));

/**
 * TR IBAN'indaki banka kodu. TR IBAN'i: `TR` + 2 kontrol + **5 hane
 * banka kodu** + 1 rezerv + 16 hane hesap. EFT kodlari DORT hanedir ve
 * alana SOLDAN SIFIRLA doldurulur ("0062" -> "00062") — bu yuzden SON
 * DORT hane alinir. TR disinda `null`: kodun yeri ulkeye gore degisir
 * ve uydurmak YANLIS banka adi yazdirirdi.
 */
export function bankaKodu(ham: string | null | undefined): string | null {
  const iban = ibanTemizle(ham);
  if (iban.length < 9 || !iban.startsWith("TR")) return null;
  return iban.slice(4, 9).slice(-4);
}

export function bankaAdiCoz(ham: string | null | undefined): string | null {
  const kod = bankaKodu(ham);
  return kod ? (TR_BANKALAR[kod] ?? null) : null;
}
