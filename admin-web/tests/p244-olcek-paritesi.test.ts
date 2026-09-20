// (P244 §1) OLCEK PARITESI — "Buyuk" gorunum modu sessizce eksik kalmasin.
//
// =========================================================================
// NE OLCULUYOR
// =========================================================================
// P243 §4'te eklenen gorunum modu (`:root.yz-buyuk`) yazi boyu ve kontrol
// yuksekliklerini ezer. Tasarim sistemine YENI bir olcu token'i eklenip
// buyuk mod blogu guncellenmezse, gozu iyi gormeyen kullanici o tek
// token'da STANDART boyu gormeye devam eder — ve bunu kimse fark etmez,
// cunku ekran "calisiyor" gorunur.
//
// P244 arayuzu bastan asagi elden geciriyor ve bu tur yeni token'lar
// eklenecek. Kural yapisal: her `--yz-fs-*` buyuk modda da TANIMLI olmali.
//
// =========================================================================
// NEDEN "TANIMLI MI" DEGIL "DAHA BUYUK MU"
// =========================================================================
// Yalniz varligi olcmek yetmez: birinin yanlislikla ayni degeri
// kopyalamasi da sessiz bir kusurdur. Bu yuzden buyuk moddaki degerin
// standarttan GERCEKTEN buyuk oldugu da olculuyor.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const CSS = readFileSync(join(__dirname, "..", "app", "tasarim-sistemi.css"), "utf8");

/**
 * `:root.yz-buyuk` blogunun govdesi.
 *
 * NEDEN AYRI ISLEVLER: olcu token'lari TEK bir `:root` blogunda degil —
 * yuzey/renk tokenlari bir `:root`ta, olcu tokenlari ("temadan bagimsiz"
 * bolumu) BASKA bir `:root`ta duruyor. Ilk yazimda yalniz ILK blogu
 * okudum ve tarama BOS dondu; "vakum degil" testi tam bunun icin vardi
 * ve gorevini yapti. */
function buyukGovde(): string {
  const i = CSS.indexOf(":root.yz-buyuk");
  if (i < 0) throw new Error("`:root.yz-buyuk` blogu yok");
  const bas = CSS.indexOf("{", i);
  return CSS.slice(bas + 1, CSS.indexOf("}", bas));
}

/** Buyuk mod blogu DISINDA kalan her sey (standart olcekler). */
function standartGovde(): string {
  const i = CSS.indexOf(":root.yz-buyuk");
  const son = CSS.indexOf("}", CSS.indexOf("{", i));
  return CSS.slice(0, i) + CSS.slice(son);
}

/** `--ad: 14px;` -> 14 (px olmayan degerler icin null). */
function pikseller(kaynak: string): Map<string, number> {
  const m = new Map<string, number>();
  for (const e of kaynak.matchAll(/^\s*(--yz-fs-[a-z0-9-]+)\s*:\s*([0-9.]+)px\s*;/gm)) {
    m.set(e[1], Number(e[2]));
  }
  return m;
}

describe("(P244 §1) olcek paritesi — Buyuk gorunum modu", () => {
  const standart = pikseller(standartGovde());
  const buyuk = pikseller(buyukGovde());

  it("TARAMA gercekten calisiyor (vakum degil)", () => {
    // Bir kilit, olctugunu bulamiyorsa hicbir sey soylemez.
    expect(standart.size).toBeGreaterThanOrEqual(8);
    expect(buyuk.size).toBeGreaterThanOrEqual(8);
    expect(standart.has("--yz-fs-body")).toBe(true);
  });

  it("her `--yz-fs-*` BUYUK modda da tanimli", () => {
    const eksik = [...standart.keys()].filter((k) => !buyuk.has(k));
    expect(
      eksik,
      `buyuk modda tanimsiz kalan olcu token'lari: ${eksik.join(", ")}`,
    ).toEqual([]);
  });

  it("buyuk moddaki her deger standarttan GERCEKTEN buyuk", () => {
    const kusurlu: string[] = [];
    for (const [ad, deger] of standart) {
      const b = buyuk.get(ad);
      if (b !== undefined && b <= deger) kusurlu.push(`${ad}: ${deger} -> ${b}`);
    }
    expect(kusurlu, `buyumeyen token: ${kusurlu.join(" · ")}`).toEqual([]);
  });

  it("KONTROL YUKSEKLIGI de buyur", () => {
    // Yazi buyuyup kutu buyumezse metin kirpilir — P243 §4'te olculmustu.
    const buyukBlok = CSS.slice(CSS.indexOf(":root.yz-buyuk input"));
    expect(buyukBlok).toMatch(/min-height:\s*5[0-9]px/);
  });
});
