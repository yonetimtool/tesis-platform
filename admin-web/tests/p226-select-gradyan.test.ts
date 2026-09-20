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

/** Verilen CSS metnindeki, degeri `gradient(` iceren `--yz-*` tokenlari. */
function tokenlariAyikla(css: string): string[] {
  const bulunan = new Set<string>();
  for (const m of css.matchAll(/(--yz-[a-z0-9-]+)\s*:\s*([^;]+);/g)) {
    if (/gradient\(/.test(m[2])) bulunan.add(m[1]);
  }
  return [...bulunan];
}

/** Tasarim sistemindeki gradyan token'lari. */
function gradyanTokenlari(): string[] {
  return tokenlariAyikla(
    readFileSync(join(KOK, "app", "tasarim-sistemi.css"), "utf8"),
  );
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

  // (P244 §1) TEHLIKE SINIFI BOSALDI — KILIT KALDI.
  // -----------------------------------------------------------------
  // P244'te "fircalanmis metal" dili emekliye ayrildi ve TUM gradyan
  // token'lari duz dolguya indi (`--yz-metal-1` artik `#ffffff`).
  // Yani bu turun kusuru artik URETILEMEZ durumda.
  //
  // TEST SILINMEDI: yarin biri yeniden bir gradyan token eklerse tuzak
  // geri gelir ve jsdom onu YINE goremez (kusur prod'a tam da bu yuzden
  // cikmisti). Kilit, tehlike sinifi bosken de ANLAMLI olmali.
  //
  // Bu yuzden iddia degisti: "liste dolu olmali" yerine "tarayici
  // GERCEKTEN calisiyor olmali". Tarayicinin calistigi, bilinen bir
  // gradyan metni uzerinde AYRICA olculuyor — liste bos ciktiginda
  // bunun sebebi "gradyan kalmadi" mi yoksa "tarayici bozuldu" mu,
  // ayirt edilebilsin.
  it("TARAYICI CALISIYOR — tehlike sinifi bos olsa bile", () => {
    const sahte = `:root {
      --yz-duz: #ffffff;
      --yz-gradyanli: linear-gradient(180deg, #fff 0%, #eee 100%);
    }`;
    expect(tokenlariAyikla(sahte)).toEqual(["--yz-gradyanli"]);
  });

  it("BUGUN gradyan token'i YOK (duz dile gecildi)", () => {
    // Bilgi amacli ve bilincli: bu iddia bir gun degisirse, degistiren
    // kisi asagidaki kuralin devreye girdigini de bilerek degistirir.
    expect(GRADYANLAR).toEqual([]);
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
