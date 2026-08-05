// TUR 56 — CANLI BOLGE DENETIMI.
//
// Hata kutusu ekrana SONRADAN gelir. `role="alert"` (ya da `aria-live`) yoksa
// ekran okuyucu yeni metni DUYURMAZ: gormeyen kullanici kaydin neden
// gitmedigini anlamaz, formda bekler. Tur 30/44'un axe denetimi bunu
// yakalamaz — axe VAR OLAN yapiyi olcer, "duyurulmasi gerekirdi" demez.
//
// Tarama TEK BIR `className` degeri icinde hem kutu zeminini (`bg-red-50`)
// hem hata metni tonunu (`text-red-6/7/800`) arar; o eleman canli bolge
// OLMALIDIR. Iki tonun AYNI dizgede olmasi sarti onemli: ilk surumde 400
// karakterlik pencereye bakiyordum ve `schematic`teki YOGUNLUK PALETINI
// (`bg-red-600` + `text-red-700`, ayri alanlar) hata kutusu sanip yanlis
// alarm uretti.
import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";


/** `className="..."` / `className={`...`}` degerleri + ofsetleri. */
function siniflar(metin: string): { deger: string; ofset: number }[] {
  const out: { deger: string; ofset: number }[] = [];
  const re = /className=(?:"([^"]*)"|\{`([^`]*)`\}|\{"([^"]*)"\})/g;
  for (const m of metin.matchAll(re)) {
    out.push({ deger: m[1] ?? m[2] ?? m[3] ?? "", ofset: m.index ?? 0 });
  }
  return out;
}

describe("canli bolge (tur 56)", () => {
  it("hata kutulari role=alert ya da aria-live tasir", () => {
    const bulgular: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      const metin = readFileSync(yol, "utf8");
      for (const { deger, ofset } of siniflar(metin)) {
        if (!/bg-red-50\b/.test(deger)) continue;
        if (!/text-red-(600|700|800)\b/.test(deger)) continue;
        // Elemanin ACILISINDAN itibaren oznitelikleri incele: `<` geriye,
        // `>` ileriye.
        const bas = metin.lastIndexOf("<", ofset);
        const son = metin.indexOf(">", ofset);
        const eleman = metin.slice(bas, son < 0 ? ofset : son);
        if (/role=\{?"alert"|aria-live=/.test(eleman)) continue;
        const satir = metin.slice(0, bas).split("\n").length;
        bulgular.push(`${yol}:${satir}  hata kutusu canli bolge DEGIL`);
      }
    }
    expect(
      bulgular,
      `Ekran okuyucu bu hatalari duyurmaz (role="alert" ekleyin):\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });
});
