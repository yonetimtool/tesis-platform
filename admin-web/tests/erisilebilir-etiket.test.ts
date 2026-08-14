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

    // (P154 / Asama 7.2) ORTAK ILKELIN KENDISI: `ParolaAlani` bir girdi
    // CIZER ama adini KENDISI tasimaz — adi cagiran taraftaki `<Field>`
    // ya da `<label>` verir ve tarama dosyalar arasini goremez.
    //
    // MUAFIYET BEDAVA DEGIL: asagidaki "her cagri yeri etiketli" testi bu
    // varsayimi OLCER. Yalniz muaf tutup gecmek, ilkeli etiketsiz
    // kullanan bir sayfayi sessizce onaylamak olurdu.
    if (yol.endsWith("components/ParolaAlani.tsx")) return;

    // (P160 / Asama 3) AYNI SINIF, AYNI EMSAL: `components/ui/alan.tsx`
    // form PRIMITIFLERI cizer (`Alan`, `CokSatir`, `Secim`) ve adlarini
    // KENDILERI tasimaz — adi `AlanSarmal` verir, `htmlFor`/`id` bagini
    // o kurar. Tarama dosyalar arasini goremez.
    //
    // MUAFIYET BEDAVA DEGIL: asagidaki "yeni form ilkelleri etiketli
    // kullaniliyor" testi bu varsayimi OLCER.
    //
    // `AramaAlani` BU DOSYADA ama muafiyete IHTIYACI YOK: kendi `sr-only`
    // etiketini ciziyor ve zorunlu `etiket` prop'u aliyor.
    if (yol.endsWith("components/ui/alan.tsx")) return;

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

  // (P160) MUAFIYETIN BEDELI — `ParolaAlani` icin kurulan desenin aynisi.
  //
  // `Alan`/`CokSatir`/`Secim` adsiz cizilebilir; kurali saglayan sey
  // ONLARIN `AlanSarmal` icinde kullanilmasidir. Bu test her cagri
  // yerini denetler. BUGUN CAGRI YERI YOK (bilesenler yeni yazildi ve
  // sayfalar henuz tasinmadi) — test o yuzden bugun bos gecer, ama
  // TASIMA BASLAYINCA calisir. Kilidi tasimadan ONCE koymak, ilk
  // etiketsiz kullanimin sessizce girmesini engeller.
  it("yeni form ilkelleri ETIKETLI kullaniliyor (AlanSarmal ya da aria-label)", () => {
    const ilkeller = /<(Alan|CokSatir|Secim)\b/;
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      // Ilkellerin KENDI dosyasi disarida: tanim orada.
      if (yol.endsWith("components/ui/alan.tsx")) continue;
      const kaynak = readFileSync(yol, "utf8");
      const satirlar = kaynak.split("\n");
      satirlar.forEach((satir, i) => {
        if (!ilkeller.test(satir)) return;
        if (/^\s*(\/\/|\*|\{\/\*)/.test(satir)) return;
        const parca = satirlar.slice(i, i + 8).join("\n");
        if (/aria-label/.test(parca)) return;
        const onceki = satirlar.slice(Math.max(0, i - 16), i).join("\n");
        // `AlanSarmal` YA DA duz `<label>`: ikisi de gecerli ad kaynagi.
        // Duz `<label>` ilk yazimda unutulmustu ve ustteki `ParolaAlani`
        // kontrolu onu ZATEN kabul ediyordu — iki kontrolun ayni kurali
        // farkli tanimlamasi tutarsizdi. Sarmalayan bir `<label>`
        // (icinde `sr-only` metinle bile olsa) erisilebilir adi GERCEKTEN
        // veriyor; reddetmek dogru kullanimi cezalandirmakti.
        if (/<(AlanSarmal|label)\b/.test(onceki)) return;
        sizanlar.push(`${yol}:${i + 1} ${satir.trim().slice(0, 50)}`);
      });
    }
    expect(sizanlar, "etiketsiz form ilkeli kullanimi").toEqual([]);
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

describe("(P154 / Asama 7.2) ParolaAlani cagri yerleri ETIKETLI", () => {
  it("her kullanim bir Field/label icinde", () => {
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      if (yol.endsWith("components/ParolaAlani.tsx")) continue;
      const satirlar = readFileSync(yol, "utf8").split("\n");
      satirlar.forEach((satir, i) => {
        if (!/<ParolaAlani\b/.test(satir)) return;
        const onceki = satirlar.slice(Math.max(0, i - 16), i).join("\n");
        // (P160) `AlanSarmal` EKLENDI: yeni tasarim dilinin form
        // sarmalayicisi GERCEK bir `<label>` cizer ve `htmlFor`/`id`
        // bagini kendisi kurar. Ustelik `etiket` prop'u TIP SEVIYESINDE
        // ZORUNLU — yani `Field`ten DAHA GUCLU bir garanti veriyor.
        // Taramanin gormedigi sey bilesenin ICI; adi tanitmak yeterli.
        if (/<(Field|AlanSarmal|label|motion\.label)\b/.test(onceki)) return;
        sizanlar.push(`${yol}:${i + 1}`);
      });
    }
    expect(sizanlar, "etiketsiz ParolaAlani").toEqual([]);
  });

  it("olcum BOSA DUSMUYOR — en az bir kullanim var", () => {
    const kullanim = taranacakDosyalar(["app", "components"]).filter(
      (y) =>
        !y.endsWith("components/ParolaAlani.tsx") &&
        /<ParolaAlani\b/.test(readFileSync(y, "utf8")),
    );
    expect(kullanim.length).toBeGreaterThanOrEqual(5);
  });
});
