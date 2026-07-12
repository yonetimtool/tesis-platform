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
    <html lang="tr">
      <body>{children}</body>
    </html>
  );
}
