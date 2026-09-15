// (P236) GENISLIK CAKISMASI KILIDI — jsdom'un GOREMEDIGI kusur sinifi.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// `<Secim className="w-32 shrink-0">` yazilmisti. `Secim`/`Alan`/`CokSatir`
// KENDI siniflarinda `w-full` tasiyor; ikisi de `width` kuruyor ve hangisinin
// kazandigi CLASS SIRASINA DEGIL, Tailwind'in URETTIGI CSS SIRASINA bagli.
// Tailwind 3.4.6 ciktisi OLCULDU:
//
//     .w-32  { width: 8rem }   <- once
//     .w-full{ width: 100% }   <- SONRA => KAZANAN
//
// Sonuc: telefon alanindaki ulke secici %100 genislik aldi, `shrink-0`
// yuzunden kuculmedi ve NUMARA ALANI SIFIR GENISLIGE indi. Kullanici ulkeyi
// secebiliyor ama numarayi YAZAMIYOR.
//
// ===========================================================================
// NEDEN KAYNAK TARAMASI, NEDEN DAVRANIS TESTI DEGIL
// ===========================================================================
// jsdom DUZEN HESAPLAMAZ: `offsetWidth` her zaman 0 doner, `getComputedStyle`
// class'lari coozmez. Kusur canlida gorunurdu ama DOM testlerinin HEPSI
// gecti — nitekim gecti de. Bu sinif ancak KAYNAKTAN yakalanabilir.
//
// Ayni sinifin daha onceki uyesi: `<select>` arka planina gradyan token
// koymak (secenekler gorunmez olur, jsdom goremez).
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";

/** `w-full` tasiyan ilkeller — genislik onlarin ICINDE tanimli. */
const ILKELLER = ["Alan", "Secim", "CokSatir"];

/** `//` ve `/* *​/` yorumlarini siler. */
function yorumsuz(s: string): string {
  return s
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .map((l) => l.replace(/\s*\/\/.*$/, ""))
    .join("\n");
}

/**
 * Ilkelin USTUNE genislik sinifi gecen yerler.
 *
 * Mantik AYRI fonksiyonda: kasitli kusurlu bir ornekle sinanabilsin diye.
 * Depoda ihlal kalmadigi icin "gecen" bir tarama calistigini KANITLAMAZ.
 */
export function genislikIhlalleri(kaynak: string, yol: string): string[] {
  const temiz = yorumsuz(kaynak);
  const bulgular: string[] = [];
  for (const ad of ILKELLER) {
    // `<Secim ... className="... w-32 ...">` — acilis etiketinin icinde.
    const desen = new RegExp(
      `<${ad}\\b[^>]*className=["\`][^"\`]*\\bw-(?!full\\b)[\\w./\\[\\]-]+`,
      "g",
    );
    for (const m of temiz.matchAll(desen)) {
      const satir = temiz.slice(0, m.index).split("\n").length;
      bulgular.push(`${yol}:${satir}  <${ad}> ustune genislik sinifi`);
    }
  }
  return bulgular;
}

describe("(P236) genislik cakismasi", () => {
  it("DEDEKTOR: tarama KASITLI kusuru gorur", () => {
    expect(
      genislikIhlalleri('<Secim className="w-32 shrink-0">', "o.tsx"),
    ).toHaveLength(1);
    expect(
      genislikIhlalleri('<Alan className="w-1/2" />', "o.tsx"),
    ).toHaveLength(1);
    // GENISLIK OLMAYAN sinif ihlal DEGIL.
    expect(
      genislikIhlalleri('<Secim className="shrink-0 tabular-nums">', "o.tsx"),
    ).toHaveLength(0);
    // `w-full` ZATEN ilkelin kendi degeri — tekrarlamak zararsiz.
    expect(genislikIhlalleri('<Alan className="w-full" />', "o.tsx")).toHaveLength(0);
    // SARMALAYICI DIV dogru cozum — ihlal DEGIL.
    expect(
      genislikIhlalleri('<div className="w-32 shrink-0"><Secim /></div>', "o.tsx"),
    ).toHaveLength(0);
    // YORUMDAKI ornek bulgu sayilmaz.
    expect(
      genislikIhlalleri('// <Secim className="w-32">', "o.tsx"),
    ).toHaveLength(0);
  });

  it("HICBIR ILKELE genislik sinifi gecilmiyor", () => {
    const bulgular = taranacakDosyalar(["app", "components"]).flatMap((f) =>
      genislikIhlalleri(readFileSync(f, "utf8"), f),
    );
    expect(
      bulgular,
      "Genislik ilkelin ICINDE (`w-full`) tanimli; ustune gecilen sinif " +
        "Tailwind'in CSS sirasina gore sessizce KAYBEDILIR. Genisligi " +
        "SARMALAYICI BIR DIV'e verin:\n" +
        bulgular.join("\n"),
    ).toEqual([]);
  });

  it("EN AZ OTUZ ilkel kullanimi taraniyor (bos kume 'temiz' sayilmasin)", () => {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der.
    const metin = taranacakDosyalar(["app", "components"])
      .map((f) => yorumsuz(readFileSync(f, "utf8")))
      .join("\n");
    const sayi = ILKELLER.reduce(
      (t, ad) => t + (metin.match(new RegExp(`<${ad}\\b`, "g"))?.length ?? 0),
      0,
    );
    expect(sayi).toBeGreaterThanOrEqual(30);
  });
});
