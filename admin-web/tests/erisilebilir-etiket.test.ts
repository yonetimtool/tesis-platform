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

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

describe("erisilebilir etiket", () => {
  it("her form denetiminin bir ADI var", () => {
    const sizanlar: string[] = [];
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      const satirlar = readFileSync(yol, "utf8").split("\n");
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
    }
    expect(sizanlar, "adsiz form denetimi").toEqual([]);
  });
});
