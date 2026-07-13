import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Tesis Yönetim Paneli",
  description: "Multi-tenant tesis operasyon SaaS — yönetim paneli",
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
