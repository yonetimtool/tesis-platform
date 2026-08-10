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

import { taranacakDosyalar } from "./tarama";

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


/**
 * (P137) Bir kaynaktaki `dark:` ONEKSIZ renk siniflari.
 *
 * Tespit ayri isleve cikarildi cunku bu dosya ikinci vakum turunun
 * CANLI ORNEGIDIR: P132.8'de buraya yazilan token kilidinin regex'ine
 * Python kacisi yuzunden BACKSPACE karakteri girmis, hicbir sey
 * eslesmemis ve test SESSIZCE gecmisti. Mutasyon yakalamasa fark
 * edilmeyecekti. Asagidaki pozitif kontroller o senaryoyu kalici olarak
 * kapatir.
 */
export function devrilmemisSiniflar(
  kaynak: string,
  kalip: RegExp,
  bilinen: (sinif: string) => boolean,
): string[] {
  const eksik: string[] = [];
  for (const m of kaynak.matchAll(kalip)) {
    if (m[1]) continue; // `dark:` onekli — zaten koyu tema icin yazilmis
    const sinif = m[2];
    if (bilinen(sinif)) continue;
    if (!eksik.includes(sinif)) eksik.push(sinif);
  }
  return eksik;
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
    for (const yol of taranacakDosyalar(["app", "components"])) {
      const kaynak = readFileSync(yol, "utf8");
      for (const s of devrilmemisSiniflar(
        kaynak,
        new RegExp(kalip.source, "g"),
        (x) => devrilmis.has(x) || GEREKCELI.has(x),
      )) {
        if (!eksik.has(s)) eksik.set(s, yol);
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
    // (P154 / Asama 7.4) Ayni sinif: bagimlilik uyarisinin turuncu ve
    // geri-donus seridinin mavi kenarligi. Ikisi de METIN TASIMAZ ve
    // durumu (eksik tanim / donus bekliyor) iki temada da AYNI anlamla
    // isaretler; uzerlerindeki tint zemin `bg-accent-*` zaten muaf.
    "border-accent-orange",
    "border-accent-blue",
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
    for (const yol of taranacakDosyalar(["app", "components"])) {
      const kaynak = readFileSync(yol, "utf8");
      for (const s of devrilmemisSiniflar(kaynak, new RegExp(kalip.source, "g"), (x) =>
        // Tint ZEMINLER (`bg-accent-blue/12`) anlam tasir ve iki temada da
        // AYNI kalir; uzerlerindeki METIN (`text-vurguInk-*`) devrilir.
        x.startsWith("bg-accent-") || TOKEN_GEREKCELI.has(x) || devrilmisToken.has(x),
      )) {
        if (!eksik.has(s)) eksik.set(s, yol);
      }
    }
    expect(
      [...eksik].map(([s, y]) => `${s} (${y})`),
      "koyu temada devrilmemis TASARIM TOKEN'i",
    ).toEqual([]);
  });
});

// (P137) POZITIF KONTROLLER — bu dosya ikinci vakum turunun CANLI
// ORNEGIDIR. P132.8'de buraya yazilan token kilidinin regex'ine bir kacis
// hatasi yuzunden BACKSPACE karakteri girmisti; hicbir sey eslesmiyordu ve
// test SESSIZCE geciyordu. Mutasyon surmeseydim fark edilmeyecekti.
//
// Asagidaki kontroller o senaryoyu kalici kapatir: desen bozulursa bunlar
// duser, cunku YAKALAMA bekliyorlar (yokluk degil).
describe("(P137) koyu tema desenleri GERCEKTEN atesliyor", () => {
  const PALET_KALIBI = new RegExp(
    `(dark:)?\\b((?:text|bg|border)-(?:${AILE})-\\d{2,3})\\b`,
    "g",
  );
  const TOKEN_KALIBI = new RegExp(
    "(dark:)?\\b((?:text|bg|border)-(?:metin|yuzey|accent|vurguInk|primary)" +
      "(?:-[A-Za-z]+)*|kart-kenar)\\b",
    "g",
  );

  it("PALET deseni devrilmemis sinifi yakalar", () => {
    const bulunan = devrilmemisSiniflar(
      '<p className="text-slate-600">x</p>',
      PALET_KALIBI,
      () => false,
    );
    expect(bulunan).toEqual(["text-slate-600"]);
  });

  it("PALET deseni `dark:` onekli olani RAHAT birakir", () => {
    expect(
      devrilmemisSiniflar('<p className="dark:text-slate-600">x</p>', PALET_KALIBI, () => false),
    ).toEqual([]);
  });

  it("TOKEN deseni devrilmemis token'i yakalar", () => {
    expect(
      devrilmemisSiniflar('<p className="text-metin-body">x</p>', TOKEN_KALIBI, () => false),
    ).toEqual(["text-metin-body"]);
  });

  it("TOKEN deseni DEVRILMIS olani rahat birakir", () => {
    expect(
      devrilmemisSiniflar(
        '<p className="text-metin-body">x</p>',
        TOKEN_KALIBI,
        (x) => x === "text-metin-body",
      ),
    ).toEqual([]);
  });
});
