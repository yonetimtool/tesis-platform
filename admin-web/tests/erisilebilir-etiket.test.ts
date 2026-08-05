// (P63) FORM DENETIMLERININ ERISILEBILIR ADI — sinif kilidi.
//
// Ekran okuyucu bir metin kutusunu ADIYLA duyurur. Ad yoksa yalnizca
// "metin kutusu" der ve gormeyen kullanici neyi doldurdugunu bilmez.
// YER TUTUCU (`placeholder`) ad DEGILDIR: yazmaya baslayinca kaybolur ve
// bazi okuyucular hic okumaz.
//
// Olculdu: panelde dort denetimin adi yoktu — yetki arama kutusu, finans
// tur suzgeci, yonetisim aktarim kutusu ve **bir TESISI SILME onayi**.
// Sonuncusu en agiriydi: adini duyamayan kullanici, ne yazdigini bilmeden
// yikici bir islemi onaylardi.
//
// KURAL: her `input`/`select`/`textarea` ya bir `Field`/`label` icinde
// olmali ya da `aria-label` tasimali. Onay kutulari ve gizli alanlar
// disaridadir (onlarin adi cevrelerindeki metinden gelir ya da hic
// gorunmezler).
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";


/**
 * Bir kaynaktaki ADSIZ form denetimleri.
 *
 * (P137) Tespit ayri isleve cikarildi — sentetik ornekle iki yonde
 * sinanabilsin diye.
 */
export function adsizDenetimler(yol: string, kaynak: string): string[] {
  const sizanlar: string[] = [];
  const satirlar = kaynak.split("\n");
  satirlar.forEach((satir, i) => {
    if (!/<(input|select|textarea)\b/.test(satir)) return;
    // Yorum icindeki ornekler denetim degildir.
    if (/^\s*(\/\/|\*|\{\/\*)/.test(satir)) return;

    const blok = satirlar.slice(i, i + 14).join("\n");
    const kapanis = blok.indexOf("/>");
    const parca = kapanis === -1 ? blok.slice(0, 500) : blok.slice(0, kapanis + 2);
    if (/type="(hidden|checkbox|radio)"/.test(parca)) return;
    if (/aria-label/.test(parca)) return;

    // SARMALAYICI PENCERESI GENIS TUTULDU: bir denetim `<Field>` icinde
    // uc dallanmanin ("bool ise ... secim ise ... degilse") en son
    // dalinda olabilir ve acilis 16 satir yukarida kalir. Dar pencere,
    // etiketli denetimleri hata gibi gosterirdi.
    const onceki = satirlar.slice(Math.max(0, i - 16), i).join("\n");
    if (/<(Field|label|motion\.label)\b/.test(onceki)) return;

    sizanlar.push(`${yol}:${i + 1} ${satir.trim().slice(0, 50)}`);
  });
  return sizanlar;
}

describe("erisilebilir etiket", () => {
  it("her form denetiminin bir ADI var", () => {
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      sizanlar.push(...adsizDenetimler(yol, readFileSync(yol, "utf8")));
    }
    expect(sizanlar, "adsiz form denetimi").toEqual([]);
  });

  // (P137) POZITIF KONTROL — desen atesliyor mu.
  it("POZITIF KONTROL: adsiz girdi YAKALANIR", () => {
    const bozuk = ['<div>', '  <input type="text" value={x} />', "</div>"].join("\n");
    expect(adsizDenetimler("sentetik.tsx", bozuk)).toHaveLength(1);
  });

  it("POZITIF KONTROL: etiketli girdi RAHAT birakilir", () => {
    const temiz = [
      "<Field label={t(\"ortakAd\")}>",
      '  <input type="text" value={x} />',
      "</Field>",
    ].join("\n");
    expect(adsizDenetimler("sentetik.tsx", temiz)).toEqual([]);
  });
});
