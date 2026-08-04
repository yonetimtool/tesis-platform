// (P132.6) KONTRAST — token'lar WCAG AA'yi tutuyor mu?
//
// Mobil tarafta bu olcum yapilmis ve KARARLARI SEKILLENDIRMISTI: vurgu
// renkleri koyu temada METIN olarak esigi tutmuyordu, o yuzden `_koyuMetin`
// haritasi var. Web ayni token'lari kullaniyorsa ayni olcumu GECMEK
// zorunda — kopyalarken kontrastin da kopyalandigini varsaymak, tam olarak
// sessiz gerileme olurdu.
//
// OLCULEN CIFTLER, gercekten ekranda YAN YANA duranlar:
//   * govde/ikincil metin  ->  kart zemini
//   * vurgu metni          ->  %12 tint zemin (chip, ikon kutusu)
//   * beyaz metin          ->  birincil dugme zemini
//   * odak halkasi         ->  yanindaki zemin (WCAG 1.4.11, esik 3)
import { describe, expect, it } from "vitest";

/** #RRGGBB -> [0-255, 0-255, 0-255] */
function rgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  return [
    parseInt(h.slice(0, 2), 16),
    parseInt(h.slice(2, 4), 16),
    parseInt(h.slice(4, 6), 16),
  ];
}

/** WCAG bagil parlaklik. */
function parlaklik(hex: string): number {
  const [r, g, b] = rgb(hex).map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function kontrast(a: string, b: string): number {
  const [x, y] = [parlaklik(a), parlaklik(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
}

/** `on` renginin `alt` uzerine `alfa` opaklikla karismis hâli (tint zemin). */
function karistir(on: string, alt: string, alfa: number): string {
  const [r1, g1, b1] = rgb(on);
  const [r2, g2, b2] = rgb(alt);
  const k = (a: number, b: number) => Math.round(a * alfa + b * (1 - alfa));
  return `#${[k(r1, r2), k(g1, g2), k(b1, b2)]
    .map((v) => v.toString(16).padStart(2, "0"))
    .join("")}`;
}

// --- token'lar (tailwind.config.ts / globals.css ile AYNI) ----------------
const ACIK = { card: "#FFFFFF", bg: "#F4F6FA", heading: "#111827", body: "#374151", muted: "#6B7280" };
const KOYU = { card: "#171C25", bg: "#0F131A", heading: "#F3F4F6", body: "#D1D5DB", muted: "#9CA3AF" };
const VURGU = {
  blue: "#2563EB",
  green: "#16A34A",
  orange: "#F59E0B",
  purple: "#8B5CF6",
  red: "#EF4444",
};
/** ACIK temada METIN olarak kullanilan koyulastirilmis tonlar
 *  (tailwind `vurguInk`) — mobil `okunurVurgu()` donusumunun onceden
 *  hesaplanmis hâli. HAM vurgu yalniz IKON/DOLGU icindir. */
const VURGU_INK = {
  blue: "#0A3696",
  green: "#0C6E30",
  orange: "#8D5A02",
  purple: "#3705A8",
  red: "#A30A0A",
};
/** Koyu temada METIN olarak kullanilan acik tonlar (mobil `_koyuMetin`). */
const VURGU_KOYU = {
  blue: "#7CA9FF",
  green: "#4ADE80",
  orange: "#FBBF24",
  purple: "#B69CFB",
  red: "#FCA5A5",
};
const TINT = 0.12;
const AA = 4.5;
const UI = 3; // WCAG 1.4.11 — metin olmayan ogeler (halka, kenarlik)

describe("(P132.6) metin kontrasti — AA (4.5)", () => {
  for (const [ad, tema, zemin] of [
    ["acik", ACIK, ACIK.card],
    ["koyu", KOYU, KOYU.card],
  ] as const) {
    it(`${ad} tema: baslik/govde/ikincil metin kart zemininde`, () => {
      for (const alan of ["heading", "body", "muted"] as const) {
        const o = kontrast(tema[alan], zemin);
        expect(o, `${ad}/${alan} = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(AA);
      }
    });

    it(`${ad} tema: SAYFA zemini icin ayri ikincil ton gecer`, () => {
      // OLCUM BIR KUSUR BULDU: `muted` (#6B7280) beyaz KARTTA 4.83 ile
      // gecerken sayfa zemininde (#F4F6FA) 4.47 ile DUSUYORDU. Sayfa
      // zemini icin ayri bir ton tanimlandi (`mutedBg`); koyu temada
      // kart ve zemin yeterince yakin oldugu icin ayrim gerekmiyor.
      const ton = ad === "acik" ? "#636C7A" : tema.muted;
      const o = kontrast(ton, tema.bg);
      expect(o, `${ad}/ikincil@bg = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(AA);
    });
  }
});

describe("(P132.6) vurgu metni TINT zeminde — chip ve ikon kutusu", () => {
  it("ACIK tema: OKUNUR ton, %12 tint uzerinde", () => {
    // ILK YAZIMDA HAM VURGU OLCULDU VE DUSTU (blue 4.37 · green 2.89 ·
    // orange 1.96 · purple 3.64 · red 3.23). Kusur testte degil KODDAYDI:
    // web portu mobilin tint desenini almis ama `okunurVurgu()`
    // donusumunu almamisti. Token eklendi; olculen sey artik odur.
    const dusuk: string[] = [];
    for (const [ad, renk] of Object.entries(VURGU_INK)) {
      const zemin = karistir(VURGU[ad as keyof typeof VURGU], ACIK.card, TINT);
      const o = kontrast(renk, zemin);
      if (o < AA) dusuk.push(`${ad}=${o.toFixed(2)}`);
    }
    // Bilgi amacli degil KURAL: chip metni okunmali.
    expect(dusuk, `tint zeminde AA altinda: ${dusuk.join(", ")}`).toEqual([]);
  });

  it("KOYU tema: ACIK TON, %12 tint uzerinde", () => {
    const dusuk: string[] = [];
    for (const [ad, renk] of Object.entries(VURGU_KOYU)) {
      // Tint zemini HAM vurgudan uretilir (dolgu ham renkte kalir), metin
      // acik tondur — mobildeki ayrimin aynisi.
      const zemin = karistir(VURGU[ad as keyof typeof VURGU], KOYU.card, TINT);
      const o = kontrast(renk, zemin);
      if (o < AA) dusuk.push(`${ad}=${o.toFixed(2)}`);
    }
    expect(dusuk, `koyu temada AA altinda: ${dusuk.join(", ")}`).toEqual([]);
  });
});

describe("(P132.6) birincil dugme ve odak halkasi", () => {
  it("beyaz metin birincil zeminde AA", () => {
    const o = kontrast("#FFFFFF", VURGU.blue);
    expect(o, `beyaz@primary = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(AA);
  });

  it("odak halkasi her iki temada UI esigini (3) gecer", () => {
    // Halka acik temada #2563EB, koyu temada #7CA9FF (globals.css).
    expect(kontrast(VURGU.blue, ACIK.card)).toBeGreaterThanOrEqual(UI);
    expect(kontrast(VURGU.blue, ACIK.bg)).toBeGreaterThanOrEqual(UI);
    expect(kontrast(VURGU_KOYU.blue, KOYU.card)).toBeGreaterThanOrEqual(UI);
    expect(kontrast(VURGU_KOYU.blue, KOYU.bg)).toBeGreaterThanOrEqual(UI);
  });
});
