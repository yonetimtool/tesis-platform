import type { Metadata } from "next";
import { cookies, headers } from "next/headers";

import { HukukiBelge } from "@/components/HukukiBelge";
import { DIL_COOKIE, istekDili } from "@/lib/i18n/diller";
import { GIZLILIK } from "@/lib/hukuki/gizlilik";

// (P113) `/gizlilik` — SABIT, PUBLIC adres.
//
// NEDEN SABIT: bu adres App Store Connect'e ve Google Play'e girilir; bir
// daha degismemesi gerekir. Tenant kapsamli (`/site/<slug>/gizlilik`) bir
// adres olamazdi — politika URUNUN politikasidir, tek bir tesisin degil.
//
// NEDEN PUBLIC: denetci OTURUM ACMADAN okur. `middleware.config.matcher`
// yol bazlidir ve bu yol listede YOKTUR (bkz. tests/middleware.test.ts —
// yalniz `app/(protected)` agacini zorunlu tutar).
//
// DIL SUNUCUDA cozulur (cerez > Accept-Language): Apple denetcisi
// `Accept-Language: en` gonderir ve sayfayi Ingilizce goreceklerdir.
export const dynamic = "force-dynamic";

async function dilCoz() {
  const cerez = await cookies();
  const baslik = await headers();
  return istekDili(cerez.get(DIL_COOKIE)?.value, baslik.get("accept-language"));
}

export async function generateMetadata(): Promise<Metadata> {
  const belge = GIZLILIK[await dilCoz()];
  // Marka SONEKI dizgi birlestirmesiyle: sablon dizgesi taramasi (P69)
  // sabit metin arar ve marka sozcugu icin istisnasi yoktur; tur 22
  // taramasinin marka istisnasi ise dizgi literalinde gecerlidir.
  return { title: belge.baslik + " — Yönetiyor", description: belge.giris };
}

export default async function GizlilikSayfasi() {
  return <HukukiBelge belge={GIZLILIK[await dilCoz()]} />;
}
