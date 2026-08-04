// (P132) WEB TOKEN'LARI MOBIL KAYNAKLA AYNI MI?
//
// Tasarim sisteminin kaynagi `mobile/lib/src/core/theme/home_tokens.dart`.
// Web bu degerleri KOPYALAR (iki dil, iki cati) — ve kopya, kopyalandigi
// gun dogru olup ertesi gun sessizce ayrisan seydir. Kamera adres kuralinda
// (P131.1) ayni sorunu ORTAK VAKA DOSYASI ile cozmustuk; burada dosya
// formatlari cok farkli oldugu icin daha dogrudan bir yol var: Dart
// dosyasini OKU ve web temasiyla karsilastir.
//
// NE OLCULMEZ: gorunumun kendisi (ekran goruntusu karsilastirmasi bu
// depoda yok). Olculen sey DEGERLERIN esitligi — ayrisma buradan baslar.
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const DART = readFileSync(
  resolve(KOK, "mobile/lib/src/core/theme/home_tokens.dart"),
  "utf8",
);
const TW = readFileSync(resolve(KOK, "admin-web/tailwind.config.ts"), "utf8");
const CSS = readFileSync(resolve(KOK, "admin-web/app/globals.css"), "utf8");

/** `static const primary = Color(0xFF2563EB);` -> "#2563EB" */
function dartRenk(ad: string): string {
  const m = new RegExp(`${ad}\\s*=\\s*Color\\(0x(?:FF)?([0-9A-Fa-f]{6})\\)`).exec(DART);
  if (!m) throw new Error(`Dart'ta renk yok: ${ad}`);
  return `#${m[1].toUpperCase()}`;
}

/** `background: Color(0xFFF4F6FA),` — HomeSurface blogu icinde. */
function dartYuzey(blok: "_light" | "_dark", alan: string): string {
  const b = new RegExp(`${blok} = HomeSurface\\(([\\s\\S]*?)\\);`).exec(DART);
  if (!b) throw new Error(`Dart'ta yuzey blogu yok: ${blok}`);
  const m = new RegExp(`${alan}:\\s*Color\\(0x(?:FF)?([0-9A-Fa-f]{6})\\)`).exec(b[1]);
  if (!m) throw new Error(`Dart'ta yuzey alani yok: ${blok}.${alan}`);
  return `#${m[1].toUpperCase()}`;
}

/** `static const cardRadius = 16.0;` -> 16 */
function dartOlcu(ad: string): number {
  const m = new RegExp(`${ad}\\s*=\\s*([0-9.]+)`).exec(DART);
  if (!m) throw new Error(`Dart'ta olcu yok: ${ad}`);
  return Number(m[1]);
}

describe("(P132) vurgu paleti mobil ile AYNI", () => {
  const eslesme: [string, string][] = [
    ["primary", "primary"],
    ["green", "green"],
    ["orange", "orange"],
    ["purple", "purple"],
    ["red", "red"],
  ];
  for (const [dartAd, webAd] of eslesme) {
    it(`${dartAd}`, () => {
      const beklenen = dartRenk(dartAd);
      // Web'de `blue` adiyla durur (dart'ta `primary`); digerleri ayni ad.
      const anahtar = webAd === "primary" ? "blue" : webAd;
      const m = new RegExp(`${anahtar}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m, `tailwind.config.ts'te accent.${anahtar} yok`).not.toBeNull();
      expect(m![1].toUpperCase()).toBe(beklenen);
    });
  }

  it("primary kisayolu da ayni deger", () => {
    const m = /primary:\s*"(#[0-9A-Fa-f]{6})"/.exec(TW);
    expect(m![1].toUpperCase()).toBe(dartRenk("primary"));
  });
});

describe("(P132) yuzey/metin renkleri", () => {
  it("ACIK tema — tailwind", () => {
    const bekle: [string, string][] = [
      ["bg", dartYuzey("_light", "background")],
      ["card", dartYuzey("_light", "card")],
      ["divider", dartYuzey("_light", "divider")],
      ["placeholder", dartYuzey("_light", "placeholder")],
    ];
    for (const [ad, deger] of bekle) {
      const m = new RegExp(`${ad}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m, `yuzey.${ad} yok`).not.toBeNull();
      expect(m![1].toUpperCase(), ad).toBe(deger);
    }
    for (const [ad, alan] of [["heading", "heading"], ["body", "body"], ["muted", "muted"]]) {
      const m = new RegExp(`${ad}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m![1].toUpperCase(), ad).toBe(dartYuzey("_light", alan));
    }
  });

  it("KOYU tema — globals.css", () => {
    // Koyu tema web'de sayfa basina `dark:` varyantiyla DEGIL, tek yerde
    // (globals.css) cozulur; deger yine mobil kaynaktan gelir.
    const bekle: [string, string][] = [
      [".dark .bg-yuzey-bg", dartYuzey("_dark", "background")],
      [".dark .bg-yuzey-card", dartYuzey("_dark", "card")],
      [".dark .text-metin-heading", dartYuzey("_dark", "heading")],
      [".dark .text-metin-body", dartYuzey("_dark", "body")],
      [".dark .text-metin-muted", dartYuzey("_dark", "muted")],
    ];
    for (const [secici, deger] of bekle) {
      const m = new RegExp(
        `${secici.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*\\{[^}]*?(#[0-9a-fA-F]{6})`,
      ).exec(CSS);
      expect(m, `${secici} yok`).not.toBeNull();
      expect(m![1].toUpperCase(), secici).toBe(deger);
    }
  });
});

describe("(P132) olcu token'lari", () => {
  const bekle: [string, string][] = [
    ["cardRadius", "kart"],
    ["iconBoxRadius", "ikon"],
    ["chipRadius", "chip"],
  ];
  for (const [dartAd, webAd] of bekle) {
    it(`${dartAd} -> rounded-${webAd}`, () => {
      const m = new RegExp(`${webAd}:\\s*"(\\d+)px"`).exec(TW);
      expect(m, `borderRadius.${webAd} yok`).not.toBeNull();
      expect(Number(m![1])).toBe(dartOlcu(dartAd));
    });
  }

  const olculer: [string, string][] = [
    ["cardPadding", "kart"],
    ["sectionGap", "bolum"],
    ["gridGap", "izgara"],
    ["iconBox", "ikonkutu"],
    ["rowIconBox", "satirikon"],
  ];
  for (const [dartAd, webAd] of olculer) {
    it(`${dartAd} -> spacing.${webAd}`, () => {
      const m = new RegExp(`${webAd}:\\s*"(\\d+)px"`).exec(TW);
      expect(m, `spacing.${webAd} yok`).not.toBeNull();
      expect(Number(m![1])).toBe(dartOlcu(dartAd));
    });
  }
});

describe("(P132) koyu tema VURGU METNI haritasi", () => {
  // Mobilde `_koyuMetin` haritasi: 600-tonu vurgular koyu zeminde AA'yi
  // tutmaz, ayni ailenin acik tonu kullanilir. Web ayni esleme.
  it("her vurgu icin acik ton tanimli", () => {
    const cift = [...DART.matchAll(/0x(FF[0-9A-Fa-f]{6}):\s*Color\(0x(FF[0-9A-Fa-f]{6})\)/g)];
    expect(cift.length, "Dart haritasi okunamadi").toBeGreaterThanOrEqual(5);
    for (const [, , acik] of cift) {
      const hex = `#${acik.slice(2).toLowerCase()}`;
      expect(CSS.toLowerCase(), hex).toContain(hex);
    }
  });
});

describe("(P132) tint opakligi %12", () => {
  it("Dart ve web ayni opakligi kullanir", () => {
    expect(DART).toMatch(/withValues\(alpha:\s*0\.12\)/);
    const kit = readFileSync(resolve(KOK, "admin-web/components/tasarim.tsx"), "utf8");
    // Tailwind alfa sozdizimi: `/12`.
    expect(kit).toContain("bg-accent-blue/12");
  });
});
