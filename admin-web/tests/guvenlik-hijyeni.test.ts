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

import { taranacakDosyalar } from "./tarama";


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

const TUM = taranacakDosyalar(["app", "components"]);

/** (P137) Tespitler ayri islevlerde — sentetik ornekle sinanabilsin diye. */
export function relsizBlank(yol: string, kaynak: string): string[] {
  const sizanlar: string[] = [];
  for (const b of baglantilar(kaynak)) {
    if (!/target=\{?["']_blank/.test(b.metin)) continue;
    if (/rel=\{?["'][^"']*(noreferrer|noopener)/.test(b.metin)) continue;
    sizanlar.push(`${yol}:${b.satir}`);
  }
  return sizanlar;
}

export function degiskenliInnerHtml(yol: string, kaynak: string): string[] {
  const sizanlar: string[] = [];
  for (const m of kaynak.matchAll(
    /dangerouslySetInnerHTML=\{\{[\s\S]{0,600}?\}\}/g,
  )) {
    // Sablon enterpolasyonu ya da dizge birlestirme => degisken girer.
    if (/\$\{|\+\s*\w/.test(m[0])) {
      sizanlar.push(`${yol}:${kaynak.slice(0, m.index).split("\n").length}`);
    }
  }
  return sizanlar;
}

describe("guvenlik hijyeni (P95)", () => {
  it("`target=_blank` olan her baglantida `rel` VAR", () => {
    const sizanlar: string[] = [];
    for (const yol of TUM) sizanlar.push(...relsizBlank(yol, readFileSync(yol, "utf8")));
    expect(sizanlar, "rel'siz _blank baglantisi").toEqual([]);
  });

  it("`dangerouslySetInnerHTML` DEGISKEN icermez", () => {
    const sizanlar: string[] = [];
    for (const yol of TUM) {
      sizanlar.push(...degiskenliInnerHtml(yol, readFileSync(yol, "utf8")));
    }
    expect(sizanlar, "degisken iceren dangerouslySetInnerHTML").toEqual([]);
  });

  // (P137) POZITIF KONTROLLER — desenler GERCEKTEN atesliyor mu. Ustteki
  // iki test bos liste bekler; desen bozulursa liste yine bos kalir ve
  // ikisi de GECER.
  it("POZITIF KONTROL: rel'siz _blank YAKALANIR, rel'li birakilir", () => {
    expect(relsizBlank("s.tsx", '<a href="/x" target="_blank">git</a>')).toHaveLength(1);
    expect(
      relsizBlank("s.tsx", '<a href="/x" target="_blank" rel="noreferrer">git</a>'),
    ).toEqual([]);
  });

  it("POZITIF KONTROL: degiskenli innerHTML YAKALANIR, sabit birakilir", () => {
    expect(
      degiskenliInnerHtml("s.tsx", "<div dangerouslySetInnerHTML={{ __html: `<b>${x}</b>` }} />"),
    ).toHaveLength(1);
    expect(
      degiskenliInnerHtml("s.tsx", '<div dangerouslySetInnerHTML={{ __html: "<b>sabit</b>" }} />'),
    ).toEqual([]);
  });
});
