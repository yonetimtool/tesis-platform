import type { MetadataRoute } from "next";
import { headers } from "next/headers";

import { TANITIM_KOKEN } from "@/lib/tanitim/adres";
import { konakYuzeyi } from "@/lib/yuzey";

// (P127) robots.txt — KONAĞA GÖRE.
//
// Ayni uygulama uc alan adindan sunuluyor. Tanitim sitesi INDEKSLENMELI;
// `panel.*` ve `app.*` ise CALISMA ALANIDIR ve indekslenmemeli — arama
// sonucunda bir yonetim giris ekrani cikmasi ne kullaniciya yarar ne de
// bize. Tek bir statik `robots.txt` bu ayrimi yapamazdi.
export const dynamic = "force-dynamic";

export default async function robots(): Promise<MetadataRoute.Robots> {
  const yuzey = konakYuzeyi((await headers()).get("host"));
  if (yuzey !== "tanitim") {
    return { rules: [{ userAgent: "*", disallow: "/" }] };
  }
  return {
    rules: [{ userAgent: "*", allow: "/" }],
    sitemap: `${TANITIM_KOKEN}/sitemap.xml`,
  };
}
