import type { MetadataRoute } from "next";

import { SITE_ADRESI } from "@/config/site";
import { sunucudanAl } from "@/lib/backend";

/**
 * ==========================================================================
 * SITEMAP URETILIR, ELLE YAZILMAZ
 * ==========================================================================
 * `apps/tanitim-web/app/sitemap.ts` yedi yolluk ELLE YAZILMIS bir dizi —
 * orada dogru, cunku o sitenin sayfalari sabit. Dukkan'da degil: bolge
 * sayfalari isletme sayisina gore DOGAR ve OLUR (docs/dukkan/05-seo.md §3).
 *
 * F1'de yalnizca SABIT sayfalar ve kategori sayfalari var. Bolge
 * sayfalari (/{il}/{ilce}/{mahalle}/{kategori}) F3'te eklenecek ve
 * yalnizca INCE ICERIK ESIGINI GECENLER sitemap'e girecek — esik altini
 * eklemek, arama motoruna var olmayan sayfalarin haritasini cizmek olur.
 */
type Kategori = { slug: string; alt: { slug: string }[] };

const SABIT = ["/", "/talep-olustur", "/isletme-kaydi"];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const veri = await sunucudanAl<{ items: Kategori[] }>("/dukkan/kategori");
  const kategoriYollari = (veri?.items ?? []).flatMap((k) => [
    `/kategori/${k.slug}`,
    ...k.alt.map((a) => `/kategori/${a.slug}`),
  ]);

  return [...SABIT, ...kategoriYollari].map((yol) => ({
    url: `${SITE_ADRESI}${yol}`,
  }));
}
