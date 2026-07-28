// Tarih/saat bicimlendirme — DILE DUYARLI (tur 31).
//
// Tur 17'de bulunmus, ayri bir alt is olarak kayda gecmisti: panel 7 dile
// acildi ama tarihler `toLocaleString("tr-TR")` ile sabitti. Yani arayuz
// Almanca'yken tarih "28.07.2026 14:30" (TR bicimi) kaliyordu; Ingilizce'de
// beklenen "Jul 28, 2026, 2:30 PM" hic gorunmuyordu. Mobil tarafta ayni
// sinif hata tur 15'te `tarihBicimi(dil)` ile kapanmisti.
//
// PARA BUNUN DISINDADIR: `lib/money.ts` ve seffaflik panosundaki `tl()`
// BILEREK `tr-TR` kullanir — para politikasi "TL + Turkce gruplama, arayuz
// dili ne olursa olsun" der (bkz. mobil README §15).
//
// Bu modul React DISI de calisir (`lib/fetcher.ts` gibi): dili cookie'den
// okur — `lib/i18n/metin.ts` ile ayni desen.
import { tarayiciDili } from "./i18n/diller";

/// GECERSIZ TARIH KONTROLU ortak: `toLocaleString` bozuk girdide ISTISNA
/// ATMAZ, "Invalid Date" DONDURUR — eski `formatDateTime` bu yuzden ekrana
/// "Invalid Date" basiyordu (try/catch bunu yakalamaz). Tur 31'de yazilan
/// test bu ONCEDEN VAR OLAN hatayi ortaya cikardi.
function bicimle(
  iso: string,
  dil: string | undefined,
  secenek: Intl.DateTimeFormatOptions,
): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  try {
    return d.toLocaleString(dil ?? tarayiciDili(), secenek);
  } catch {
    return iso;
  }
}

/** "28.07.2026 14:30" / "7/28/26, 2:30 PM" — kisa tarih + saat. */
export function tarihSaatBicimi(iso: string, dil?: string): string {
  return bicimle(iso, dil, { dateStyle: "short", timeStyle: "short" });
}

/** "28 Tem 2026 14:30" / "Jul 28, 2026, 2:30 PM" — orta uzunlukta. */
export function tarihSaatUzun(iso: string, dil?: string): string {
  return bicimle(iso, dil, { dateStyle: "medium", timeStyle: "short" });
}

/** Yalniz tarih. Gecersiz girdi AYNEN doner (uydurma tarih gosterme). */
export function tarihBicimi(iso: string, dil?: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleDateString(dil ?? tarayiciDili());
}
