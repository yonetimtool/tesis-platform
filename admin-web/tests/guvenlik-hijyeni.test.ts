// (P95) İKİ SESSİZ GÜVENLİK KURALI.
//
// Ölçüm anında panelde **ihlal yok** — kilitlenen şey yarın da olmaması.
// İkisi de eklendiği anda hiçbir şeyi bozmaz, testler yeşil kalır ve
// gözden kacar; bedeli ancak kullanicida ortaya cikar.
//
// 1. `target="_blank"` + `rel` YOKSA: acilan sayfa `window.opener` ile
//    bizim sekmemizi BASKA BIR ADRESE yonlendirebilir (tabnabbing). Sakin
//    bir duyuru fotografina tiklar, geri dondugunde "oturumunuz doldu"
//    diyen sahte bir giris ekrani gorur. Sunucuda hicbir iz kalmaz.
// 2. `dangerouslySetInnerHTML` DEGISKEN icerirse: sunucudan ya da
//    kullanicidan gelen metin HTML olarak calisir (XSS). Panelde tek
//    kullanim yeri tema onyukleme betigidir ve SABIT bir dizgedir.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

/** Bir `<a …>` acilis etiketinin TAMAMI (cok satirli olabilir). */
function baglantilar(kaynak: string): { metin: string; satir: number }[] {
  const out: { metin: string; satir: number }[] = [];
  for (const m of kaynak.matchAll(/<a\b[\s\S]*?>/g)) {
    out.push({
      metin: m[0],
      satir: kaynak.slice(0, m.index).split("\n").length,
    });
  }
  return out;
}

const TUM = [...dosyalar("app"), ...dosyalar("components")];

describe("guvenlik hijyeni (P95)", () => {
  it("`target=_blank` olan her baglantida `rel` VAR", () => {
    const sizanlar: string[] = [];
    for (const yol of TUM) {
      const kaynak = readFileSync(yol, "utf8");
      for (const b of baglantilar(kaynak)) {
        if (!/target=\{?["']_blank/.test(b.metin)) continue;
        if (/rel=\{?["'][^"']*(noreferrer|noopener)/.test(b.metin)) continue;
        sizanlar.push(`${yol}:${b.satir}`);
      }
    }
    expect(sizanlar, "rel'siz _blank baglantisi").toEqual([]);
  });

  it("`dangerouslySetInnerHTML` DEGISKEN icermez", () => {
    const sizanlar: string[] = [];
    for (const yol of TUM) {
      const kaynak = readFileSync(yol, "utf8");
      for (const m of kaynak.matchAll(
        /dangerouslySetInnerHTML=\{\{[\s\S]{0,600}?\}\}/g,
      )) {
        // Sablon enterpolasyonu ya da dizge birlestirme => degisken girer.
        if (/\$\{|\+\s*\w/.test(m[0])) {
          sizanlar.push(`${yol}:${kaynak.slice(0, m.index).split("\n").length}`);
        }
      }
    }
    expect(sizanlar, "degisken iceren dangerouslySetInnerHTML").toEqual([]);
  });
});
