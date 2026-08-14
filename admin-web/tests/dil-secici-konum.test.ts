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

  it("MASAUSTU seridi yalniz genis ekranda ve dil secici SAG UCTA", () => {
    const kod = kodSatirlari(KABUK);
    // (P154) `justify-end` YERINE `justify-between`: serit artik IKI oge
    // tasiyor (global arama solda, dil secici sagda). Kilidin OLCTUGU sey
    // sinif adi degil ILKEYDI — "serit yalniz genis ekranda cizilir ve
    // dil secici SAG UCTA durur". Sinif adina baglanmak, ilkeyi bozmayan
    // bir duzenlemede testi dusururdu; nitekim oyle oldu.
    expect(kod).toMatch(/hidden[^"]*justify-between[^"]*lg:flex/);
    // Dil secici seridin SON ogesi: arama ondan ONCE gelir.
    //
    // (P160) SERIT UC OGEYE CIKTI (arama · bildirim merkezi · dil).
    // Kilidin OLCTUGU ILKE degismedi — "dil secici SON" — ama karakter
    // penceresi (80) araya giren bilesenle doldu. Pencere genisletmek
    // yerine SIRA ACIKCA dogrulaniyor: bu, sayi ayarlamaktan daha
    // saglam ve testin kendi cumlesini bire bir olcuyor.
    const sira = ["<GlobalArama />", "<BildirimMerkezi />", "<DilSecici />"];
    let imlec = -1;
    for (const oge of sira) {
      const yer = kod.indexOf(oge, imlec + 1);
      expect(yer, `${oge} beklenen sirada degil`).toBeGreaterThan(imlec);
      imlec = yer;
    }
  });

  it("MOBIL ust cubukta duruyor", () => {
    // Eskiden orada yalnizca hizalama icin bos bir `span` vardi.
    const kod = kodSatirlari(KABUK);
    // (P160) Mobil cubukta da bildirim merkezi araya girdi; olculen sey
    // yine SIRA: logo -> bildirim -> dil.
    const mobilSira = ["YonetioLogo size={24}", "<BildirimMerkezi />", "<DilSecici />"];
    let mobilImlec = -1;
    for (const oge of mobilSira) {
      const yer = kod.indexOf(oge, mobilImlec + 1);
      expect(yer, `${oge} mobil cubukta beklenen sirada degil`).toBeGreaterThan(
        mobilImlec,
      );
      mobilImlec = yer;
    }
  });
});
