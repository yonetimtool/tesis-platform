// (P244 §10d) KULLANILAN HER `--yz-*` TOKEN'I TANIMLI MI?
//
// ===========================================================================
// OLCULEN KUSUR — bu kilit yazilirken BULUNDU
// ===========================================================================
// `/yerel-isletmeler` bes yerde `text-[--yz-metin-soluk]` yaziyordu.
// Boyle bir token HICBIR YERDE TANIMLI DEGIL: tarayici gecersiz degeri
// atar ve metin devralinan rengi alir. Hicbir hata, hicbir uyari — yalniz
// yanlis renk.
//
// Bu kusur turu SESSIZDIR: `tsc` bir sinif dizesini denetlemez, jsdom
// rengi cozmez, goz de "biraz koyu" ile "dogru" arasindaki farki
// ekrandan ayirt edemez.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Kaynaklarda gecen her `--yz-...` adi, `app/tasarim-sistemi.css`te
// TANIMLI olmali. Yazim hatasi, yeniden adlandirma artigi ve uydurma
// token buradan duser.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");
const SISTEM = readFileSync(join(KOK, "app", "tasarim-sistemi.css"), "utf8");

/** `--yz-foo:` bicimindeki TANIMLAR. */
const TANIMLI = new Set(
  [...SISTEM.matchAll(/(--yz-[a-z0-9-]+)\s*:/g)].map((m) => m[1]),
);

function kaynaklar(): [string, string][] {
  const cikti: [string, string][] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        if (ad === "node_modules" || ad === ".next") continue;
        tara(tam);
        continue;
      }
      if (ad.endsWith(".tsx") || ad.endsWith(".ts")) {
        cikti.push([tam, readFileSync(tam, "utf8")]);
      }
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  tara(join(KOK, "lib"));
  return cikti;
}

describe("(P244 §10d) kullanilan `--yz-*` token'lari tanimli", () => {
  const DOSYALAR = kaynaklar();

  it("TARAMA gercekten calisiyor (vakum degil)", () => {
    expect(DOSYALAR.length).toBeGreaterThan(100);
    // Sistem dosyasi gercekten token tasiyor mu.
    expect(TANIMLI.size).toBeGreaterThan(40);
    expect(TANIMLI.has("--yz-text")).toBe(true);
  });

  it("TANIMSIZ token KULLANILMIYOR", () => {
    const eksik: string[] = [];
    for (const [yol, kaynak] of DOSYALAR) {
      for (const m of kaynak.matchAll(/--yz-[a-z0-9-]+/g)) {
        const ad = m[0];
        // Tanim satirinin kendisi (`--yz-x:`) sayilmaz.
        if (TANIMLI.has(ad)) continue;
        eksik.push(`${ad} (${yol.slice(KOK.length + 1)})`);
      }
    }
    expect(
      [...new Set(eksik)].sort(),
      `tanimsiz token:\n${[...new Set(eksik)].join("\n")}`,
    ).toEqual([]);
  });
});
