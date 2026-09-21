// (P244 §10d) `"use client"` DIREKTIFI ILK IFADE OLMALI.
//
// ===========================================================================
// OLCULEN KUSUR — PROD DAGITIMINI DURDURDU
// ===========================================================================
// Uc dosyada direktifin ONUNE bir `import` satiri girmisti:
//
//     import { Kart } from "@/components/ui";
//     "use client";
//
// `next build` bunu REDDEDER:
//   "The "use client" directive must be placed before other expressions."
//
// ===========================================================================
// NEDEN HICBIR KILIT YAKALAMADI — ve bu dosyanin varlik sebebi
// ===========================================================================
// `tsc` gecerli TypeScript gorur; `eslint` kural tanimiyordu; `vitest`
// modulleri kendi cati kurallariyla yukler ve Next'in direktif kuralini
// UYGULAMAZ. Yani uc dogrulama adimi da YESILDI ve hata ancak PROD
// DERLEMESINDE cikti.
//
// Ders, bu turun en pahali dersi: DOGRULAMA ZINCIRI URUNUN GERCEK
// DERLEMESINI ICERMIYORSA, o derlemenin kurallari olculmuyor demektir.
// `npm run build` artik zincirin kalici parcasi; bu dosya ise ayni
// sinifi SANIYELER icinde yakalayan ucuz on kontrol.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

function kaynaklar(): string[] {
  const cikti: string[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        if (ad === "node_modules" || ad === ".next") continue;
        tara(tam);
        continue;
      }
      if (ad.endsWith(".tsx") || ad.endsWith(".ts")) cikti.push(tam);
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  tara(join(KOK, "lib"));
  return cikti;
}

/**
 * Direktif dosyanin ILK IFADESI mi?
 *
 * YORUMLAR SERBEST: Next yalnizca IFADE'lerden once olmasini ister ve
 * depodaki dosyalarin cogu bir aciklama blokuyla basliyor. Kuralı
 * yorumlara da genisletmek, gercek kusurla ilgisi olmayan bir bicim
 * dayatmasi olurdu.
 */
export function direktifIlkMi(kaynak: string): boolean {
  let i = 0;
  const satirlar = kaynak.split("\n");
  while (i < satirlar.length) {
    const t = satirlar[i].trim();
    if (t === "" || t.startsWith("//") || t.startsWith("/*") || t.startsWith("*")) {
      i += 1;
      continue;
    }
    return t.startsWith('"use client"') || t.startsWith("'use client'");
  }
  return false;
}

describe('(P244 §10d) "use client" ilk ifade', () => {
  const DOSYALAR = kaynaklar();

  it("TARAMA gercekten calisiyor (vakum degil)", () => {
    expect(DOSYALAR.length).toBeGreaterThan(100);
    // Ayirt edici mi — sahte kaynakla dogrulanir.
    expect(direktifIlkMi('"use client";\nimport x from "y";')).toBe(true);
    expect(direktifIlkMi('// yorum\n\n"use client";\nimport x from "y";')).toBe(true);
    expect(direktifIlkMi('import x from "y";\n"use client";')).toBe(false);
  });

  it("DIREKTIF TASIYAN her dosyada direktif ILK IFADE", () => {
    const suclular: string[] = [];
    for (const yol of DOSYALAR) {
      const kaynak = readFileSync(yol, "utf8");
      // Satir basinda duran GERCEK direktif; yorum icinde gecen
      // ("use client" modulune girmez gibi) sayilmaz.
      if (!/^\s*["']use client["'];?\s*$/m.test(kaynak)) continue;
      if (!direktifIlkMi(kaynak)) suclular.push(yol.slice(KOK.length + 1));
    }
    expect(
      suclular.sort(),
      `"use client" ilk ifade DEGIL:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });
});
