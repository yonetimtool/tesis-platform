// (P226) `<select>` ARKA PLANINDA GRADYAN YASAK.
//
// ===========================================================================
// OLCULEN KUSUR (PROD)
// ===========================================================================
// Tesisler ekranindaki kurulum suzgecinde acilir liste BOS gorunuyordu:
// kullanici yalnizca secili satiri goruyor, oteki iki secenek YOK gibiydi.
//
// Sebep DOM'da degil BOYAMADA: `background: var(--yz-metal-1)` yazmistim
// ve o token bir `linear-gradient`. `<option>` satirlari select'in arka
// planini devralir ama native acilir listede gradyan UYGULANAMAZ;
// tarayici geri duser, `color` ise `--yz-text` olarak kalir. Koyu temada
// acik metin acik zeminde kaliyor ve secenekler GORUNMEZ oluyor.
//
// ===========================================================================
// NEDEN BU TEST YAPISAL
// ===========================================================================
// jsdom RENK CIZMEZ: DOM testi uc `<option>`u da dogru metinle buluyordu
// ve GECIYORDU (olculdu — kusur prod'a bu sekilde cikti). Gorunurlugu
// ancak gercek bir tarayicida olcebilirdik; onun yerine SEBEBI yasakliyoruz.
//
// Gradyan token listesi CSS'TEN URETILIR, elle yazilmaz: yeni bir gradyan
// token eklenirse bu kural onu kendiliginden kapsar.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** CSS'te degeri `gradient(` iceren tum `--yz-*` tokenlari. */
function gradyanTokenlari(): string[] {
  const css = readFileSync(join(KOK, "app", "tasarim-sistemi.css"), "utf8");
  const bulunan = new Set<string>();
  for (const m of css.matchAll(/(--yz-[a-z0-9-]+)\s*:\s*([^;]+);/g)) {
    if (/gradient\(/.test(m[2])) bulunan.add(m[1]);
  }
  return [...bulunan];
}

/** Kaynak agacindaki tum .tsx dosyalari. */
function tsxDosyalari(): string[] {
  const cikti: string[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        if (ad === "node_modules" || ad === ".next") continue;
        tara(tam);
        continue;
      }
      if (ad.endsWith(".tsx")) cikti.push(tam);
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  return cikti;
}

describe("(P226) select/option arka plani DUZ RENK olmali", () => {
  const GRADYANLAR = gradyanTokenlari();

  it("gradyan token listesi CSS'ten URETILDI (bos degil)", () => {
    // Liste bos kalirsa asagidaki kural sessizce hicbir sey olcmez.
    expect(GRADYANLAR.length).toBeGreaterThan(0);
    expect(GRADYANLAR).toContain("--yz-metal-1");
  });

  it("HICBIR <select>/<option> gradyan token'i BACKGROUND olarak kullanmaz", () => {
    const ihlal: string[] = [];
    for (const dosya of tsxDosyalari()) {
      const kaynak = readFileSync(dosya, "utf8");
      // `<select` ya da `<option`dan sonraki etiket govdesini al (ilk `>`e
      // kadar) ve icinde gradyan token'i background olarak arayan bir
      // `style` var mi diye bak.
      for (const m of kaynak.matchAll(/<(select|option)\b([\s\S]*?)>/g)) {
        const govde = m[2];
        if (!/background/.test(govde)) continue;
        for (const tok of GRADYANLAR) {
          if (new RegExp(`background[^,;}]*var\\(${tok}\\)`).test(govde)) {
            ihlal.push(`${dosya.slice(KOK.length + 1)}: <${m[1]}> ${tok}`);
          }
        }
      }
    }
    expect(
      [...new Set(ihlal)],
      "acilir listede secenekler GORUNMEZ olur (gradyan option'a " +
        `uygulanamaz):\n${[...new Set(ihlal)].join("\n")}`,
    ).toEqual([]);
  });
});
