// (P52) HAM `fetch` YANIT DENETIMI — sinif kilidi.
//
// `fetch` HTTP HATASINDA REDDETMEZ: 401 de 500 de basariyla cozulur.
// Bu yuzden `await fetch(...)` yazip `res.ok`a bakmayan her cagri,
// SUNUCU REDDETSE BILE basarili gibi devam eder. P51'de bildirimler
// sayfasinda tam olarak bu vardi: istek 500 donuyor, kullaniciya
// "okundu olarak isaretlendi" deniyordu.
//
// Kilit bu SINIFI kapatir: `app/` ve `components/` altindaki her ham
// `fetch` cagrisi ya yanit durumunu denetlemeli (`.ok` / `status`), ya
// da denetlememe gerekcesini `FETCH-DENETIMSIZ` isaretiyle YAZMALI.
// `lib/` disaridadir: istemci sarmalayicilari (apiSend, jsonFetcher,
// backend vekili) denetimi ZATEN yapar ve testin konusu odur.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";


/**
 * Tek bir kaynaktaki denetimsiz `fetch` cagrilari.
 *
 * (P137) TESPIT AYRI BIR ISLEVE CIKARILDI ki hem gercek kulliyata hem de
 * SENTETIK BOZUK bir orneğe kosulabilsin. Sebep: P136 "tarama hic dosya
 * gormedi" vakumunu kapatti; geriye IKINCI tur kaldi — dosyalar okunuyor
 * ama desen hicbir sey eslestirmiyor. O durumda liste bos kalir ve
 * `toEqual([])` yine GECER. Asagidaki pozitif kontrol tam bunu olcer.
 */
export function denetimsizFetchler(yol: string, kaynak: string): string[] {
  const sizanlar: string[] = [];
  const satirlar = kaynak.split("\n");
  satirlar.forEach((satir, i) => {
    // `jsonFetcher`/`fetcher(` gibi sarmalayici adlarini degil, ham
    // `fetch(` cagrisini ara.
    if (!/(^|[^A-Za-z.])fetch\(/.test(satir)) return;
    if (/globalThis\.fetch|typeof fetch/.test(satir)) return;
    // Cagriyi izleyen pencerede durum denetimi aranir; ayni satirda
    // `.ok` okuyan tek satirlik kullanim da gecerlidir.
    const pencere = satirlar.slice(i, i + 12).join("\n");
    if (/\.ok\b|\.status\b|FETCH-DENETIMSIZ/.test(pencere)) return;
    if (/oturumDustu|agIstegi/.test(pencere)) return; // (P101/P102)
    sizanlar.push(`${yol}:${i + 1}`);
  });
  return sizanlar;
}

describe("ham fetch denetimi", () => {
  it("her ham fetch cagrisi yanit durumunu DENETLER", () => {
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"], [".ts", ".tsx"])) {
      sizanlar.push(...denetimsizFetchler(yol, readFileSync(yol, "utf8")));
    }
    expect(sizanlar).toEqual([]);
  });

  // (P137) POZITIF KONTROL — desen GERCEKTEN atesliyor mu.
  //
  // Ustteki test bos liste bekler; desen bozulursa (bu oturumda bir
  // regex'e kacis hatasiyla backspace karakteri girmisti) liste yine bos
  // kalir ve test GECER. Bu blok sentetik bir sizinti uretip yakalandigini
  // olcer: kilit iki yonde de sinanmis olur.
  it("POZITIF KONTROL: denetimsiz fetch YAKALANIR", () => {
    const bozuk = [
      "async function kaydet() {",
      "  const res = await fetch(\"/api/x\", { method: \"POST\" });",
      "  return res.json();",
      "}",
    ].join("\n");
    expect(denetimsizFetchler("sentetik.ts", bozuk)).toHaveLength(1);
  });

  it("POZITIF KONTROL: denetlenen fetch RAHAT birakilir", () => {
    // Kilit iki yonde sinanir: yanlisi yakaliyor mu, DOGRUYU rahat
    // birakiyor mu. Yalniz ilki olculursa "her seye sizinti de" diyen bir
    // desen de gecerdi.
    const temiz = [
      "async function kaydet() {",
      "  const res = await fetch(\"/api/x\", { method: \"POST\" });",
      "  if (!res.ok) throw new Error(\"olmadi\");",
      "  return res.json();",
      "}",
    ].join("\n");
    expect(denetimsizFetchler("sentetik.ts", temiz)).toEqual([]);
  });
});
