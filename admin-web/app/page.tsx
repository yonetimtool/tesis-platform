import type { Metadata } from "next";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";

import { TanitimSayfasi } from "./tanitim-sayfasi";
import { DIL_COOKIE, DILLER, istekDili } from "@/lib/i18n/diller";
import { TANITIM_KOKEN } from "@/lib/tanitim/adres";
import { TANITIM } from "@/lib/tanitim/icerik";
import { konakYuzeyi } from "@/lib/yuzey";

// (P127) KOK ROTA — KONAĞA GÖRE İKİ FARKLI SAYFA.
//
// Kok alan adi (yönetiyor.com / www) TANITIM sitesidir; panel.* ve app.*
// koku ise calisma alaninin baslangicidir (middleware zaten role gore
// yonlendirir, burasi yalniz gelistirme/dogrudan erisim icin yedektir).
//
// KARAR SUNUCUDA VERILIR: istemcide `window.location.host`a bakmak ilk
// kareyi yanlis sayfayla boyar (P126'da olculdu ve duzeltildi).
export const dynamic = "force-dynamic";

async function dilCoz() {
  const cerez = await cookies();
  const baslik = await headers();
  return istekDili(cerez.get(DIL_COOKIE)?.value, baslik.get("accept-language"));
}

export async function generateMetadata(): Promise<Metadata> {
  const baslik = await headers();
  if (konakYuzeyi(baslik.get("host")) !== "tanitim") return {};
  const dil = await dilCoz();
  const i = TANITIM[dil];
  // HREFLANG: ayni URL yedi dilde sunulur (dil cerez/Accept-Language ile
  // cozulur), bu yuzden `?lang=` ile ACIK bir surum de bildirilir —
  // arama motoru her dili ayri bir adresle indeksleyebilsin.
  const koken = TANITIM_KOKEN;
  const languages: Record<string, string> = {};
  for (const d of DILLER) languages[d] = `${koken}/?lang=${d}`;
  return {
    title: i.metaBaslik,
    description: i.metaAciklama,
    alternates: { canonical: koken + "/", languages },
    openGraph: {
      title: i.metaBaslik,
      description: i.metaAciklama,
      url: koken + "/",
      siteName: "Yönetiyor",
      type: "website",
    },
  };
}

export default async function Kok() {
  const baslik = await headers();
  if (konakYuzeyi(baslik.get("host")) === "tanitim") {
    return <TanitimSayfasi dil={await dilCoz()} />;
  }
  // Panel/app kokü: calisma alanina. (Middleware bunu zaten yapar; bu
  // satir middleware'in matcher'i disinda kalan bir istek icin yedektir.)
  redirect("/dashboard");
}
