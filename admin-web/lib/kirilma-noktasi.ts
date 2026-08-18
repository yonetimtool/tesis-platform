// (P169 §1) KIRILMA NOKTALARI — TEK KAYNAK.
//
// =========================================================================
// NEDEN BU DOSYA VAR
// =========================================================================
// Kirilma noktalari IKI YERDE yasiyor: Tailwind sinif onekleri (`sm:`,
// `lg:`) ve JS davranisi (orn. "DataTable dar ekranda KART modunda
// cizilsin"). Ikisi ayri sayilar tasirsa, tablo 639 px'te kart olur ama
// izgara 640'ta kirilir — arada bir piksellik bir bantta ekran BOZUK
// gorunur ve kimse sebebini bulamaz.
//
// Bu dosya o sayilarin TEK kaynagidir; `tailwind.config.ts` ile esitligi
// `tests/duyarli-kirilma.test.ts` kilitler.
//
// =========================================================================
// BANTLAR (brief §1)
// =========================================================================
//   sm  <640      telefon
//   md  640-1023  tablet dikey
//   lg  1024-1439 tablet yatay / kucuk dizustu
//   xl  >=1440    masaustu

/** Bant ADI — kod icinde piksel yazilmaz, bu adlar kullanilir. */
export type Bant = "sm" | "md" | "lg" | "xl";

/** Bandin BASLADIGI genislik (px). `sm` sifirdan baslar. */
export const BANT_ESIGI: Record<Bant, number> = {
  sm: 0,
  md: 640,
  lg: 1024,
  xl: 1440,
};

/** Buyukten kucuge — bant cozumlemesi bu sirayla yapilir. */
export const BANTLAR: readonly Bant[] = ["xl", "lg", "md", "sm"];

/** Genislikten bant. Sunucu tarafinda da calisir (saf fonksiyon). */
export function bantCoz(genislik: number): Bant {
  for (const b of BANTLAR) {
    if (genislik >= BANT_ESIGI[b]) return b;
  }
  return "sm";
}

/**
 * DOKUNMATIK GIRDI SORGUSU — genislikten AYRI bir soru.
 *
 * "Dar ekran" ile "parmakla kullaniliyor" AYNI SEY DEGILDIR: 1280 px'lik
 * bir dokunmatik dizustu genistir ama fare yoktur; 600 px'e kucultulmus
 * bir masaustu tarayici penceresi dardir ama fare vardir.
 *
 * Dokunma hedefi buyutme kararini GENISLIGE baglamak, fareyle calisan
 * dar pencerede tablolari gereksiz yere sisirirdi. `pointer: coarse`
 * dogru soruyu sorar.
 */
export const KABA_ISARETCI = "(pointer: coarse)";

/** Bir bandin medya sorgusu — `min-width` esikleri. */
export function bantSorgusu(bant: Bant): string {
  const alt = BANT_ESIGI[bant];
  const sonraki = BANTLAR[BANTLAR.indexOf(bant) - 1];
  const ust = sonraki ? BANT_ESIGI[sonraki] - 1 : null;
  if (alt === 0) return `(max-width: ${ust}px)`;
  return ust === null
    ? `(min-width: ${alt}px)`
    : `(min-width: ${alt}px) and (max-width: ${ust}px)`;
}
