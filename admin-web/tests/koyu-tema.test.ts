// (P62) KOYU TEMA KAPSAMI — sinif kilidi.
//
// Bu depoda koyu tema MERKEZIDIR: sayfalar `dark:` varyanti yazmaz,
// `app/globals.css` icindeki `.dark .<sinif>` kurallari devirir. Sonuc:
// devrilmemis bir renk sinifi kullanmak SESSIZ bir kusurdur — acik temada
// dogru gorunur, koyu temada okunmaz. Olculdu: `rose` ve `sky` aileleri
// hic devrilmemisti ve `text-rose-600/700` SAYDAM yuzeylerde kullaniliyordu
// (mesaj hatasi, finans "cikis" tutari, cikis uyarisi) — yani koyu gul
// rengi KOYU zemine dusuyordu.
//
// KURAL: `app/` ve `components/` altinda `dark:` oneki OLMADAN kullanilan
// her renk sinifi, ya `globals.css`te devrilmis olmali ya da asagidaki
// GEREKCELI listede yer almali.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

/** Devrilmesi GEREKMEYEN siniflar — her biri bir gerekceyle.
 *
 * 1. DOYGUN ZEMIN + BEYAZ METIN: `bg-*-500/600/700` ustunde `text-white`
 *    kullanilir; iki temada da ayni gorunur ve kontrast korunur.
 * 2. KOYU ZEMIN: `bg-slate-500/800/900` zaten koyudur.
 * 3. KOYU KENARLIK: koyu zeminde koyu kenarlik SILIKTIR ama okunurluk
 *    sorunu degildir (kenarlik metin tasimaz).
 * 4. BILINCLI SILIK: `text-slate-300` yetki matrisinde "izin YOK"
 *    isaretidir; silik olmasi TASARIMDIR (izin verilenler one ciksin).
 */
const GEREKCELI = new Set([
  // 1 + 2 — doygun/koyu zeminler
  "bg-amber-500", "bg-amber-700", "bg-emerald-500", "bg-emerald-700",
  "bg-indigo-500", "bg-red-500", "bg-red-600", "bg-rose-600", "bg-rose-700",
  "bg-slate-500", "bg-slate-800", "bg-slate-900",
  // 3 — kenarliklar
  "border-amber-800", "border-emerald-800", "border-indigo-600",
  "border-red-200", "border-red-700", "border-slate-600", "border-slate-900",
  // 4 — bilincli silik
  "text-slate-300",
]);

const AILE =
  "slate|gray|red|rose|amber|yellow|emerald|green|blue|indigo|violet|purple|pink|orange|teal|cyan|sky|lime|fuchsia";

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

describe("koyu tema kapsami", () => {
  it("dark: oneksiz her renk sinifi ya devrilmis ya GEREKCELI", () => {
    const css = readFileSync("app/globals.css", "utf8");
    const devrilmis = new Set(
      [...css.matchAll(new RegExp(`\\.dark \\.(?:hover\\\\:)?((?:text|bg|border)-(?:${AILE})-\\d{2,3})`, "g"))]
        .map((m) => m[1]),
    );

    const kalip = new RegExp(`(dark:)?\\b((?:text|bg|border)-(?:${AILE})-\\d{2,3})\\b`, "g");
    const eksik = new Map<string, string>();
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      const kaynak = readFileSync(yol, "utf8");
      for (const m of kaynak.matchAll(kalip)) {
        if (m[1]) continue; // `dark:` onekli — zaten koyu tema icin yazilmis
        const sinif = m[2];
        if (devrilmis.has(sinif) || GEREKCELI.has(sinif)) continue;
        if (!eksik.has(sinif)) eksik.set(sinif, yol);
      }
    }
    expect(
      [...eksik].map(([s, y]) => `${s} (${y})`),
      "koyu temada devrilmemis renk sinifi",
    ).toEqual([]);
  });

  // (P132.8) TASARIM TOKEN'LARI DA AYNI KURALA TABI.
  //
  // Sayfalar bu turda `text-slate-600` gibi PALET siniflarindan token
  // siniflarina (`text-metin-body`, `bg-yuzey-card`, `kart-kenar`...)
  // gecirildi. Ustteki tarama YALNIZ palet ailelerine bakar — yani gecis,
  // o elemanlari kilidin KAPSAMI DISINA cikardi. Bu tam olarak bu dosyanin
  // onlemek icin var oldugu sessiz bosluktur: `globals.css`teki bir `.dark`
  // kuralini silmek acik temada HICBIR SEYI bozmaz, koyu temada okunmaz
  // metin birakirdi.
  //
  // KAPSAM: renk KONTRASTI tasiyan siniflar — metin renkleri ve yuzey
  // zeminleri. Muaf olanlar asagida tek tek gerekcelendirildi; muafiyet
  // "unuttum"un degil, bir KARARIN kaydi olmali.
  const TOKEN_GEREKCELI = new Set([
    // Dolu marka zemini + uzerinde BEYAZ metin: kontrast zeminden bagimsiz,
    // iki temada da ayni (birincil dugme).
    "bg-primary",
    // Kenarlik renkleri metin tasimaz; secili/uyari durumunu iki temada da
    // ayni anlamla isaretlerler.
    "border-primary",
    "border-accent-green",
    "border-accent-red",
  ]);

  it("dark: oneksiz her TASARIM TOKEN'i da devrilmis", () => {
    const css = readFileSync("app/globals.css", "utf8");
    const devrilmisToken = new Set(
      [...css.matchAll(/\.dark \.((?:text|bg|border)-[A-Za-z]+(?:-[A-Za-z]+)*|kart-kenar)\b/g)]
        .map((m) => m[1]),
    );

    const kalip = new RegExp(
      "(dark:)?\\b((?:text|bg|border)-(?:metin|yuzey|accent|vurguInk|primary)" +
        "(?:-[A-Za-z]+)*|kart-kenar)\\b",
      "g",
    );
    const eksik = new Map<string, string>();
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      const kaynak = readFileSync(yol, "utf8");
      for (const m of kaynak.matchAll(kalip)) {
        if (m[1]) continue;
        const sinif = m[2];
        // Tint ZEMINLER (`bg-accent-blue/12`) anlam tasir ve iki temada da
        // AYNI kalir; uzerlerindeki METIN (`text-vurguInk-*`) devrilir.
        if (sinif.startsWith("bg-accent-")) continue;
        if (TOKEN_GEREKCELI.has(sinif) || devrilmisToken.has(sinif)) continue;
        if (!eksik.has(sinif)) eksik.set(sinif, yol);
      }
    }
    expect(
      [...eksik].map(([s, y]) => `${s} (${y})`),
      "koyu temada devrilmemis TASARIM TOKEN'i",
    ).toEqual([]);
  });
});
