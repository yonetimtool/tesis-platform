import type { MetadataRoute } from "next";
import { headers } from "next/headers";

import { DILLER } from "@/lib/i18n/diller";
import { TANITIM_KOKEN } from "@/lib/tanitim/adres";
import { konakYuzeyi } from "@/lib/yuzey";

// (P127) sitemap.xml — YALNIZ tanitim yuzeyinde anlamli.
//
// Dort PUBLIC adres var: kok, gizlilik, kosullar, hesap-silme. Calisma alani rotalari
// BILEREK YOK — hepsi oturum arkasindadir ve haritaya koymak, tarayiciyi
// 302 zincirine sokup indeks butcesini bosa harcatirdi.
//
// Tarih SABIT DEGIL, dagitim aninda: `new Date()` her istekte degisirdi
// ve `lastModified` her taramada "degisti" derdi. Icerik degisiminde
// elle guncellenecek TEK yer burasi.
export const dynamic = "force-dynamic";

const GUNCELLEME = new Date("2026-08-04T00:00:00Z");

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const yuzey = konakYuzeyi((await headers()).get("host"));
  if (yuzey !== "tanitim") return [];
  const koken = TANITIM_KOKEN;
  const diller = Object.fromEntries(
    DILLER.map((d) => [d, `${koken}/?lang=${d}`]),
  ) as Record<string, string>;
  return [
    {
      url: `${koken}/`,
      lastModified: GUNCELLEME,
      changeFrequency: "monthly",
      priority: 1,
      alternates: { languages: diller },
    },
    { url: `${koken}/gizlilik`, lastModified: GUNCELLEME, changeFrequency: "yearly", priority: 0.3 },
    { url: `${koken}/kosullar`, lastModified: GUNCELLEME, changeFrequency: "yearly", priority: 0.3 },
    // (P141.3) Play'in ZORUNLU tuttugu girissiz silme sayfasi.
    { url: `${koken}/hesap-silme`, lastModified: GUNCELLEME, changeFrequency: "yearly", priority: 0.3 },
  ];
}
