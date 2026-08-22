import type { Metadata, Viewport } from "next";

import { AltBilgi } from "@/components/AltBilgi";
import { UstMenu } from "@/components/UstMenu";
import { SITE_ADRESI } from "@/config/site";

import "./globals.css";
import "./yazi-tipi.css";

/**
 * (P177) TANITIM SITESI KOK DUZENI.
 *
 * TEK DIL: Turkce. Panel yedi dillidir cunku icinde yasayan kullanicilar
 * yedi dilli; tanitim sitesinin okuyucusu Turkiye'deki site
 * yoneticisidir. Yedi dilli bir tanitim sitesi, yedi kez guncellenmesi
 * gereken bir pazarlama metni demekti ve bugun karsiligi yok. Karar
 * docs/P177-kararlar.md'de.
 *
 * ANALITIK / IZLEYICI YOK: sartname §0 acikca yasakliyor. Bu dosyada
 * hicbir ucuncu taraf betigi yoktur ve `tests/harici-istek.test.ts`
 * kaynak agacini tarayip dis alan adi geciyorsa duser.
 */
export const metadata: Metadata = {
  metadataBase: new URL(SITE_ADRESI),
  title: {
    default: "Yönetiyor — site ve apartman yönetimi",
    template: "%s — Yönetiyor",
  },
  description:
    "Aidat, arıza, duyuru, rezervasyon ve güvenlik turları tek uygulamada. " +
    "Yöneticiler siteyi kurar, sakinler uygulamadan katılır.",
  applicationName: "Yönetiyor",
  alternates: { canonical: "/" },
  icons: {
    icon: "/marka/favicon.ico",
    apple: "/marka/apple-touch-icon.png",
  },
  openGraph: {
    type: "website",
    siteName: "Yönetiyor",
    url: SITE_ADRESI,
    locale: "tr_TR",
  },
};

export const viewport: Viewport = {
  themeColor: "#EAF1FA",
  width: "device-width",
  initialScale: 1,
};

export default function KokDuzen({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr">
      <head>
        {/* Latin dilimi ON YUKLENIR: ilk boyamada baslik yazi tipiyle
            cizilsin. Yalniz `latin` — `latin-ext` yalnizca Turkce'ye ozgu
            harflerde devreye girer ve tarayici onu kendisi ceker. */}
        <link
          rel="preload"
          href="/fonts/inter-latin.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
      </head>
      <body>
        {/* Klavye kullanicisi menuyu her sayfada bastan gecmesin.
            `focus:not-sr-only` gizlemeyi kaldirir; gorunur hâlin KENDI
            zemini ve dolgusu olmali, yoksa bag icerigin ustune ciplak
            metin olarak duser ve okunmaz. */}
        <a
          href="#icerik"
          className="gizli-erisilebilir focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-[10px] focus:bg-lacivert focus:px-4 focus:py-2.5 focus:font-bold focus:text-white"
        >
          İçeriğe geç
        </a>
        <UstMenu />
        <main id="icerik">{children}</main>
        <AltBilgi />
      </body>
    </html>
  );
}
