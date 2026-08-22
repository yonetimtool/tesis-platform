// ==========================================================================
// (P177 §3) FIYAT SABITLERI — TEK DOSYA.
// ==========================================================================
// Sartname: "Fiyat sabitleri koda gomulmeyecek, tek dosyada duracak."
// Hesaplayici, /yonetici sayfasindaki ozet ve kayit formundaki rozet
// UCU DE buradan okur; bir fiyat degisikligi tek satirdir.
//
// KARAR VERILDI (sartname): aralik 1-500 daire, adim 1, varsayilan 50,
// KADEME YOK. Yani tutar dogrusaldir: daire x yillik birim fiyat.

/** Daire basina YILLIK liste fiyati (TL). KDV HARIC. */
export const YILLIK_DAIRE_FIYATI_TL = 100;

/** Sürgü ve sayisal kutunun ortak sinirlari. */
export const DAIRE_EN_AZ = 1;
export const DAIRE_EN_COK = 500;
export const DAIRE_ADIM = 1;
export const DAIRE_VARSAYILAN = 50;

/**
 * Yillik tutar. Girdi HER ZAMAN once sinirlanir: sayisal kutuya elle
 * 9999 yazan bir kullanici, surgunun uretemeyecegi bir tutar gormemeli.
 */
export function yillikTutar(daire: number): number {
  return sinirla(daire) * YILLIK_DAIRE_FIYATI_TL;
}

/** [DAIRE_EN_AZ, DAIRE_EN_COK] araligina tamsayi olarak sikistirir. */
export function sinirla(daire: number): number {
  if (!Number.isFinite(daire)) return DAIRE_VARSAYILAN;
  return Math.min(DAIRE_EN_COK, Math.max(DAIRE_EN_AZ, Math.round(daire)));
}

/**
 * "5.000 ₺" — Turkce binlik ayraci.
 *
 * `Intl` KULLANILIYOR ama `style: "currency"` KULLANILMIYOR: o bicim
 * "₺5.000,00" uretir ve kurusu olmayan bir yillik tutarda iki sifir
 * gurultudur. Simge sona konur (Turkce yazim).
 */
export function tutarBicimle(tl: number): string {
  return `${new Intl.NumberFormat("tr-TR").format(tl)} ₺`;
}

/**
 * KDV UYARISI — SARTNAMEDE BIREBIR VERILEN METIN. Degistirilmemeli:
 * fiyatin yaninda KDV durumunu yazmak yasal bir zorunluluktur ve
 * ifadenin kendisi kabul kriteridir (§9.4).
 */
export const KDV_UYARISI = "Fiyatlarımıza KDV dahil değildir.";
