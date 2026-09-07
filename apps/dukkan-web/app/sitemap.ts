import type { MetadataRoute } from "next";

import { INCE_ICERIK_ESIGI, SITE_ADRESI } from "@/config/site";
import { sunucudanAl } from "@/lib/backend";

/**
 * ==========================================================================
 * SITEMAP URETILIR, ELLE YAZILMAZ
 * ==========================================================================
 * `apps/tanitim-web/app/sitemap.ts` yedi yolluk ELLE YAZILMIS bir dizi —
 * orada dogru, cunku o sitenin sayfalari sabit. Dukkan'da degil: bolge
 * sayfalari isletme sayisina gore DOGAR ve OLUR.
 *
 * YALNIZ ESIGI GECENLER GIRER. Esik alti sayfalar `noindex` ve sitemap'te
 * yok — ikisini birden yapmak gerekli: sitemap'e koyup `noindex` demek,
 * arama motoruna celiskili sinyal gondermek olurdu.
 *
 * SIRALAMA ISLETME SAYISINA GORE (uc oyle donuyor): 50.000 URL sinirina
 * dayanildiginda kesilen kisim EN AZ isletmeli sayfalar olur — yani en az
 * degerli olanlar.
 */
export const revalidate = 86400;

type Kalem = { il: string; ilce: string; mahalle: string; kategori: string };
type Kategori = { slug: string; alt: { slug: string }[] };

const SABIT = ["/", "/talep-olustur", "/isletme-kaydi", "/giris"];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const kat = await sunucudanAl<{ items: Kategori[] }>("/dukkan/kategori", 86400);
  const bolge = await sunucudanAl<{ items: Kalem[] }>(
    `/dukkan/sitemap/sayfalar?esik=${INCE_ICERIK_ESIGI}`,
    86400,
  );

  const yollar = [
    ...SABIT,
    ...(kat?.items ?? []).flatMap((k) => [
      `/kategori/${k.slug}`,
      ...k.alt.map((a) => `/kategori/${a.slug}`),
    ]),
    ...(bolge?.items ?? []).map(
      (b) => `/${b.il}/${b.ilce}/${b.mahalle}/${b.kategori}`,
    ),
  ];

  // Next.js tek dosyada 50.000 URL siniri koyuyor; uc de ayni tavanla
  // donuyor. Yine de burada KESIYORUZ: iki yerde tavan olmasi, birinin
  // bir gun degismesi durumunda sessizce gecersiz bir sitemap uretmeyi
  // onluyor.
  return yollar.slice(0, 50000).map((yol) => ({ url: `${SITE_ADRESI}${yol}` }));
}
