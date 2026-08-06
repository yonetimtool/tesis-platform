import type { Metadata } from "next";
import { cookies, headers } from "next/headers";
import { HukukiBelge } from "@/components/HukukiBelge";
import { DIL_COOKIE, istekDili } from "@/lib/i18n/diller";
import { HESAP_SILME } from "@/lib/hukuki/hesap-silme";
// (P141.3) `/hesap-silme` — SABIT, PUBLIC adres.
//
// Play sarti: hesap silme sayfasi GIRISSIZ erisilebilir olmali. `/gizlilik`
// ile AYNI desen kullanildi (public yol, sunucuda dil cozumu) — ikinci bir
// yol icat etmek, middleware'in public yol listesini iki yerde tutmak
// olurdu.
//
// DIL SUNUCUDA cozulur (cerez > Accept-Language): Play denetcisi
// `Accept-Language: en` gonderir ve sayfayi Ingilizce gorur.
export const dynamic = "force-dynamic";

async function dilCoz() {
  const cerez = await cookies();
  const baslik = await headers();
  return istekDili(cerez.get(DIL_COOKIE)?.value, baslik.get("accept-language"));
}

export async function generateMetadata(): Promise<Metadata> {
  const belge = HESAP_SILME[await dilCoz()];
  return { title: belge.baslik + " — Yönetio", description: belge.giris };
}

export default async function HesapSilmeSayfasi() {
  return <HukukiBelge belge={HESAP_SILME[await dilCoz()]} />;
}
