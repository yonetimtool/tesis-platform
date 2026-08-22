import type { MetadataRoute } from "next";

/**
 * PWA manifest. Ikonlar `scripts/ikon-uret.py` ciktisidir (§8) —
 * ikinci bir kaynak yok.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Yönetiyor",
    short_name: "Yönetiyor",
    description: "Site ve apartman yönetimi",
    start_url: "/",
    display: "browser",
    background_color: "#EAF1FA",
    theme_color: "#EAF1FA",
    lang: "tr",
    icons: [
      { src: "/marka/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/marka/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
