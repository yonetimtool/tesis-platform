import type { MetadataRoute } from "next";

import { SITE_ADRESI } from "@/config/site";

/**
 * Kayit BFF rotalari indekslenmez: arama motorunun POST uclarini
 * taramasinin bir anlami yok ve hata gunluklerini kirletirdi.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: "/api/" },
    sitemap: `${SITE_ADRESI}/sitemap.xml`,
  };
}
