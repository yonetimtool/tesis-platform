// (P251 §4) TABLO AGIRLIKLI SAYFALAR DAHA GENIS.
//
// Icerik `max-w-7xl` (1280 px) ile sinirliydi: 1920 px ekranda kenar
// cubugundan sonra iki yanda ~190 px bos kaliyor, cok sutunlu tablolar ise
// yatay kaydiriliyordu. Ozet, formlar ve okuma sayfalari P244/P245
// duzeninde (1280) KALIR — uzun satirlar genis ekranda okunmaz olur. Yalniz
// asagidaki tablo agirlikli sayfalar 1680 px'e kadar genisler.
//
// ONEK eslesmesi: `/finans` -> `/finans/tahsilatlar` de genis.
export const GENIS_ROTALAR: readonly string[] = [
  "/units",
  "/users",
  "/residents",
  "/tasks",
  "/finans",
  "/dues",
  "/raporlar",
  "/reports",
  "/tanimlar",
  "/ice-aktarim",
  "/panik",
  "/gonderim-gunlugu",
  "/audit",
  "/tenants",
  "/assets",
  "/arac-gecisleri",
  "/davetler",
  "/complaints",
  "/bakim",
  "/vardiya-plani",
];

export function genisSayfaMi(yol: string | null | undefined): boolean {
  if (!yol) return false;
  return GENIS_ROTALAR.some((r) => yol === r || yol.startsWith(`${r}/`));
}
