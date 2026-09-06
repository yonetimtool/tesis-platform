import type { Metadata } from "next";

import { SITE_ADI, SITE_ADRESI } from "@/config/site";

import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_ADRESI),
  title: {
    default: `${SITE_ADI} — Bölgendeki Usta ve Hizmet Firmaları`,
    template: `%s | ${SITE_ADI}`,
  },
  description:
    "Mahallendeki elektrikçi, tesisatçı, temizlik ve tadilat ustalarını bul; " +
    "ihtiyacını anlat, teklifleri karşılaştır.",
  // Tek dil (tr). Yonetiyor 7 dilli ama yerel esnaf aramasi Turkce
  // yapiliyor; cok dilli SEO ayri bir is ve yarim yapilirsa zararli
  // (docs/dukkan/05-seo.md §7).
  alternates: { canonical: "/" },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="tr">
      <body>{children}</body>
    </html>
  );
}
