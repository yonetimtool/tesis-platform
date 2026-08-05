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

/**
 * Bir kaynaktaki CANLI BOLGE olmayan hata kutulari.
 *
 * (P137) Tespit ayri bir isleve cikarildi ki sentetik bir orneğe de
 * kosulabilsin — bkz. asagidaki pozitif kontrol.
 */
export function cansizHataKutulari(yol: string, metin: string): string[] {
  const bulgular: string[] = [];
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
  return bulgular;
}

const SENTETIK_CANSIZ =
  '<div className="rounded bg-red-50 p-3 text-red-700">Bir hata olustu</div>';
const SENTETIK_CANLI =
  '<div role="alert" className="rounded bg-red-50 p-3 text-red-700">Bir hata olustu</div>';

describe("canli bolge (tur 56)", () => {
  it("hata kutulari role=alert ya da aria-live tasir", () => {
    const bulgular: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      bulgular.push(...cansizHataKutulari(yol, readFileSync(yol, "utf8")));
    }
    expect(
      bulgular,
      `Ekran okuyucu bu hatalari duyurmaz (role="alert" ekleyin):\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });

  // (P137) POZITIF KONTROL: desen GERCEKTEN atesliyor mu. Ustteki test bos
  // liste bekler; desen bozulursa liste yine bos kalir ve test GECER.
  it("POZITIF KONTROL: cansiz hata kutusu YAKALANIR", () => {
    expect(cansizHataKutulari("sentetik.tsx", SENTETIK_CANSIZ)).toHaveLength(1);
  });

  it("POZITIF KONTROL: role=alert tasiyan kutu RAHAT birakilir", () => {
    expect(cansizHataKutulari("sentetik.tsx", SENTETIK_CANLI)).toEqual([]);
  });
});
