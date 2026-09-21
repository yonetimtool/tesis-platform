// (P245) `TabloBasligi` ICINDE IKINCI BIR `<Tr>` OLMAZ.
//
// ===========================================================================
// OLCULEN KUSUR — PROD'DA HIDRASYON DUSURUYORDU
// ===========================================================================
// `TabloBasligi` `<tr>`i KENDI cizer. On bes cagri yerinin DOKUZU
// icerigi ayrica bir `<Tr>` ile sariyordu:
//
//     <TabloBasligi>
//       <Tr>            <-- ikinci <tr>
//         <Th>...</Th>
//
// Ortaya `<tr><tr>` cikiyor — GECERSIZ HTML. Tarayici ic `<tr>`i disari
// tasiyor, sunucu ciziminden FARKLI bir agac olusuyor ve React
// hidrasyonu DUSUYOR ("Hydration failed..."). Sonucunda sayfanin tamami
// istemcide yeniden ciziliyordu.
//
// ===========================================================================
// NEDEN HICBIR TEST GORMEDI
// ===========================================================================
// `tsc` JSX'in HTML GECERLILIGINI denetlemez; jsdom ic ice `<tr>`i
// sessizce kabul eder ve gorunum neredeyse ayni kalir. Kusur ancak
// GERCEK TARAYICIDA, ekran goruntusu alinirken konsolda gorundu.
//
// Bu dosya o kusfu saniyeler icinde yakalayan ucuz on kontrol: kaynak
// metninde `<TabloBasligi>`den hemen sonra `<Tr>` gelmemeli.
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
      if (ad.endsWith(".tsx")) cikti.push(tam);
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  return cikti;
}

/** `<TabloBasligi ...>` ve ardindan (bosluk/yorum atlayarak) `<Tr`. */
const DESEN = /<TabloBasligi[^>]*>\s*(?:\{\/\*[\s\S]*?\*\/\}\s*)?<Tr\b/;

describe("(P245) TabloBasligi icinde ikinci `<Tr>` yok", () => {
  const DOSYALAR = kaynaklar();

  it("TARAMA gercekten calisiyor (vakum degil)", () => {
    expect(DOSYALAR.length).toBeGreaterThan(100);
    // Desen GERCEKTEN esliyor mu — sahte kaynakta dogrulanir.
    expect(DESEN.test("<TabloBasligi>\n  <Tr>\n    <Th>x</Th>")).toBe(true);
    expect(DESEN.test("<TabloBasligi>\n  <Th>x</Th>")).toBe(false);
    // En az bir dosya bu bileseni GERCEKTEN kullaniyor olmali.
    expect(
      DOSYALAR.some((f) => readFileSync(f, "utf8").includes("<TabloBasligi")),
    ).toBe(true);
  });

  it("HICBIR cagri yeri icerigi `<Tr>` ile SARMIYOR", () => {
    const suclular: string[] = [];
    for (const yol of DOSYALAR) {
      if (DESEN.test(readFileSync(yol, "utf8"))) {
        suclular.push(yol.slice(KOK.length + 1));
      }
    }
    expect(
      suclular.sort(),
      `TabloBasligi icinde ikinci <Tr>:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });
});
