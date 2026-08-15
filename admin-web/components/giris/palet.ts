/**
 * (P162) GIRIS EKRANI PALETI — sartnamenin §3'u birebir.
 *
 * =========================================================================
 * NEDEN AYRI PALET, NEDEN `--yz-*` DEGIL
 * =========================================================================
 * Brief'in acik karari: "giris ekrani ayri bir yuzeydir (vitrin), panel
 * calisma alanidir. Giris sartnamedeki paleti kullanir, panel mevcut
 * dilinde kalir."
 *
 * Bu yuzden buradaki renkler tasarim sistemine BAGLANMAZ. Baglansaydi iki
 * sonuc dogardi: ya vitrin metalik grilesirdi, ya panel lacivertlesirdi.
 * Ikisi de istenmiyor. Giris ekrani TEK bir rotadir ve kendi kapali
 * paletini tasir; sizinti olmamasi icin token uretmiyoruz.
 *
 * TEMADAN ETKILENMEZ: vitrin her zaman koyudur. Panelin acik/koyu temasi
 * girisi degistirmez — bir vitrinin gece ve gunduz ayni gorunmesi gibi.
 */

/** Deep navy — zemin katmanlari (uzaktan yakina). */
export const NAVY_DIP = "#061426";
export const NAVY_ORTA = "#081B2E";
export const NAVY_YAKIN = "#0B2438";

/** Turkuaz ailesi — vurgu, node ve CTA. */
export const TURKUAZ_KOYU = "#10B8B2";
export const TURKUAZ = "#18C7C0";
export const TURKUAZ_ACIK = "#42D8CF";
export const CYAN_YUMUSAK = "#65E6E0";

/** Ikincil mavi — uzak yorungeler. */
export const MAVI_IKINCIL = "#153B59";

/** Cam yuzey. */
export const CAM_ZEMIN = "rgba(255,255,255,0.08)";
export const CAM_KENAR = "rgba(255,255,255,0.20)";
export const CAM_ZEMIN_KOYU = "rgba(255,255,255,0.06)";
/** Mobil kart zemini — blur yerine OPAKLIK ile ayirir (bkz. GirisFormu). */
export const CAM_ZEMIN_MOBIL = "rgba(9,26,44,0.82)";
export const CAM_KENAR_ZAYIF = "rgba(255,255,255,0.18)";

/** Metin kademeleri. */
export const METIN = "#F5FAFA";
export const METIN_IKINCIL = "rgba(255,255,255,0.65)";
export const METIN_SOLUK = "rgba(255,255,255,0.40)";

/** Kurumsal easing — sartname §12. */
export const EGRI = "cubic-bezier(0.16,1,0.3,1)";
export const EGRI_DIZI = [0.16, 1, 0.3, 1] as const;

/**
 * SAHNE GIRIS ZAMAN CIZELGESI (sartname §28), saniye cinsinden.
 *
 * Sirayi kodda dagitmak yerine tek yerde tutuyoruz: sira degisirse
 * bilesenler degil BU dizi degisir.
 */
export const GIRIS_SIRASI = {
  zemin: 0,
  yorunge: 0.2,
  logo: 0.4,
  baslik: 0.55,
  aciklama: 0.7,
  kart: 0.8,
  form: 1.0,
  cta: 1.2,
} as const;
