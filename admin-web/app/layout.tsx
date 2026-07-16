import type { Metadata } from "next";

import "./globals.css";

// `icons` BILEREK yazilmaz: app/icon.svg'yi Next kendisi bulup
// <link rel="icon" href="/icon.svg?<hash>"> olarak enjekte eder. Hash dosya
// degisince degisir → tarayici yeni faviconu ceker.
//
// Elle `icons: { icon: "/icon.svg" }` yazmak bu otomatigi EZIYOR ve URL'yi
// hash'siz birakiyordu; Next ise bu rotayi `immutable, max-age=31536000` ile
// sunuyor. Sonuc: logo degisse bile tarayicilar eski faviconu BIR YIL boyunca
// yeniden istemiyordu (hard refresh cogu tarayicida bunu asmaz).
export const metadata: Metadata = {
  title: "Yönetio Panel",
  description: "Yönetio — çok kiracılı tesis operasyon SaaS yönetim paneli",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="tr" suppressHydrationWarning>
      <head>
        {/* Ilk boyamadan once tema sinifini ata (FOUC yok). Kayitli tercih
            yoksa/sistem ise OS temasini izle. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme');var d=t==='dark'||((!t||t==='system')&&window.matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);}catch(e){}})();`,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
