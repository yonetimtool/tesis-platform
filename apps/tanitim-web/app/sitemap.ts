import type { MetadataRoute } from "next";

import { SITE_ADRESI } from "@/config/site";

const YOLLAR = [
  "/",
  "/yonetici",
  "/yonetici/kayit",
  "/site-sakini",
  "/kullanici-sozlesmesi",
  "/kvkk-aydinlatma",
  "/cerez-politikasi",
];

export default function sitemap(): MetadataRoute.Sitemap {
  return YOLLAR.map((yol) => ({ url: `${SITE_ADRESI}${yol}` }));
}
