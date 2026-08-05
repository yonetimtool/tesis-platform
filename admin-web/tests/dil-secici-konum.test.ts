// (P140.4) DIL SECICI SAG USTTE — VE TEK YERDE.
//
// Kerem: "sag ust koseye tasinacak; su anki konumundan kaldirilacak (iki
// yerde birden durmasin)". Ikinci sart en az birincisi kadar onemli:
// ayni denetimin iki kopyasi "hangisi gecerli?" sorusunu uretir ve
// birinde yapilan duzeltme otekinde unutulur.
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const KABUK = readFileSync("components/AppShell.tsx", "utf8");

/** Yorum satirlarini atar: kilidin GEREKCESI de bu adlari anlatiyor. */
function kodSatirlari(s: string): string {
  return s
    .split("\n")
    .filter((l) => !/^\s*(\/\/|\*|\{\/\*|\/\*)/.test(l))
    .join("\n");
}

describe("(P140.4) dil secici konumu", () => {
  it("kabukta TEK kez cizilmiyor — mobil ust cubuk + masaustu serit", () => {
    // Iki YER var ama ikisi BIRBIRINI DISLAR (`lg:hidden` / `lg:flex`):
    // ayni anda yalnizca biri gorunur. Olculen sey "kac kez yazildigi"
    // degil, KENAR CUBUGUNDA KALMADIGI.
    const kod = kodSatirlari(KABUK);
    const sayi = [...kod.matchAll(/<DilSecici\s*\/>/g)].length;
    expect(sayi).toBe(2);
  });

  it("KENAR CUBUGU ALTINDAN kaldirildi (tema anahtari kaldi)", () => {
    const kod = kodSatirlari(KABUK);
    // Tema anahtarinin yanindaki eski konum: `<ThemeToggle />` ile ayni
    // kutuda `<DilSecici />` OLMAMALI.
    const kutu = /<ThemeToggle \/>\s*<DilSecici \/>/.test(kod);
    expect(kutu, "dil secici hala kenar cubugu altinda").toBe(false);
    expect(kod).toContain("<ThemeToggle />");
  });

  it("MASAUSTU seridi SAGA hizali ve yalniz genis ekranda", () => {
    const kod = kodSatirlari(KABUK);
    expect(kod).toMatch(/hidden justify-end[^"]*lg:flex/);
  });

  it("MOBIL ust cubukta duruyor", () => {
    // Eskiden orada yalnizca hizalama icin bos bir `span` vardi.
    const kod = kodSatirlari(KABUK);
    expect(kod).toMatch(/YonetioLogo size=\{24\}[\s\S]{0,120}<DilSecici \/>/);
  });
});
