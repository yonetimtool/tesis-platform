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

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (/\.tsx?$/.test(ad)) cikti.push(yol);
  }
  return cikti;
}

describe("ham fetch denetimi", () => {
  it("her ham fetch cagrisi yanit durumunu DENETLER", () => {
    const sizanlar: string[] = [];
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      const satirlar = readFileSync(yol, "utf8").split("\n");
      satirlar.forEach((satir, i) => {
        // `jsonFetcher`/`fetcher(` gibi sarmalayici adlarini degil, ham
        // `fetch(` cagrisini ara.
        if (!/(^|[^A-Za-z.])fetch\(/.test(satir)) return;
        if (/globalThis\.fetch|typeof fetch/.test(satir)) return;
        // Cagriyi izleyen pencerede durum denetimi aranir; ayni satirda
        // `.ok` okuyan tek satirlik kullanim da gecerlidir.
        const pencere = satirlar.slice(i, i + 12).join("\n");
        if (/\.ok\b|\.status\b|FETCH-DENETIMSIZ/.test(pencere)) return;
        sizanlar.push(`${yol}:${i + 1}`);
      });
    }
    expect(sizanlar).toEqual([]);
  });
});
