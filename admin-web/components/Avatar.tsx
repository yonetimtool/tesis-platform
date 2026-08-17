"use client";

// (P167 §1.7) AVATAR — fotograf varsa fotograf, yoksa BAS HARFLER.
//
// NEDEN BAS HARF, NEDEN GENEL BIR "kisi" IKONU DEGIL: sag ust kosedeki
// avatar bir susleme degil, HANGI HESAPLA girildiginin gostergesi. Ayni
// tarayicida iki tesise (ya da yonetici + sakin hesabina) giren kullanici
// icin tek fark odur. Herkese ayni gri silueti cizmek o farki silerdi.
//
// RENK ADDAN TURETILIR, rastgele DEGIL: ayni kisi her acilista ayni rengi
// alir. Rastgele renk, "hesap degisti mi?" sorusunu her yenilemede yeniden
// sordururdu.

import { Foto } from "@/components/Foto";

/**
 * Adin bas harfleri — en fazla iki harf.
 *
 * `toLocaleUpperCase("tr")` SART: Turkce'de `i` -> `I`dir. Varsayilan
 * buyutme "Ilker"i "ILKER" yapar ve bas harf yanlis cikar.
 *
 * Bosluklara gore bolunur; tek kelimelik adda ilk IKI harf alinir ("Ku")
 * — tek harf, iki farkli kisiyi ayirt etmek icin fazla zayif.
 */
export function basHarfler(ad: string): string {
  const parcalar = ad.trim().split(/\s+/).filter(Boolean);
  if (parcalar.length === 0) return "";
  if (parcalar.length === 1) {
    return parcalar[0].slice(0, 2).toLocaleUpperCase("tr");
  }
  return (
    parcalar[0].charAt(0) + parcalar[parcalar.length - 1].charAt(0)
  ).toLocaleUpperCase("tr");
}

/**
 * Addan kararli bir renk tonu (0-359).
 *
 * Toplama tabanli basit bir ozet yeter: amac carpismayi onlemek degil,
 * AYNI kisiye AYNI rengi vermek. Kriptografik bir ozet burada yalnizca
 * maliyet olurdu.
 */
function tonu(ad: string): number {
  let toplam = 0;
  for (const ch of ad) toplam = (toplam + ch.codePointAt(0)!) % 360;
  return toplam;
}

export function Avatar({
  ad,
  src,
  boy = 32,
}: {
  ad: string;
  src?: string | null;
  /** Kenar uzunlugu (px). Yazi boyu bundan turetilir. */
  boy?: number;
}) {
  const olcu = { width: boy, height: boy };

  if (src) {
    // OLCU SARMALDA, `Foto`da DEGIL: `Foto` bir `style` alani almiyor ve
    // sirf avatar icin ona bir tane eklemek, o bileseni her cagiranin
    // olcuyu kendi cozmesine kapi acardi. Sarmal ayrica `Foto`nun HATA
    // halini (kirik/suresi dolmus presigned URL) de ayni kare icinde
    // tutar — duzen kaymaz.
    //
    // Boyut satir-ici cunku Tailwind sinifi DINAMIK olamaz: JIT sinif
    // adini kaynakta ARAR, `h-[${boy}px]` hicbir zaman uretilmez.
    return (
      <span
        className="block shrink-0 overflow-hidden rounded-full"
        style={olcu}
      >
        {/* `object-cover`: kare olmayan fotograf ESNETILMEZ, kirpilir. */}
        <Foto src={src} alt={ad} className="h-full w-full object-cover" />
      </span>
    );
  }

  const h = tonu(ad);
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-full font-semibold"
      style={{
        ...olcu,
        fontSize: Math.round(boy * 0.4),
        // Koyu/acik temada da okunur: doygunlugu dusuk zemin + ayni tonun
        // koyu metni. Sabit bir metin rengi (beyaz) acik temada zemine
        // yaklasip kontrasti dusururdu.
        background: `hsl(${h},45%,82%)`,
        color: `hsl(${h},60%,24%)`,
      }}
    >
      {basHarfler(ad)}
    </span>
  );
}
