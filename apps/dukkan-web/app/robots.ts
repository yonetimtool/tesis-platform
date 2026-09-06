import type { MetadataRoute } from "next";

import { SITE_ADRESI } from "@/config/site";

/**
 * Arama sonuclari ve BFF rotalari INDEKSLENMEZ.
 *
 * Filtre kombinasyonlari sonsuz sayida URL uretir; her biri ayni
 * isletmeleri farkli siralarla gosterir. Indekslenirlerse kendi bolge
 * sayfalarimizla YARISIRLAR (ic kopya icerik).
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/ara", "/ben/"] }],
    sitemap: `${SITE_ADRESI}/sitemap.xml`,
  };
}
