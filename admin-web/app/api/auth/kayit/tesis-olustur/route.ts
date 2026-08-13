import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P155r2 / §3) YONETICI SELF-SIGNUP — tesis uygulamadan/panelden acilir.
 *
 * Jetonlar GOVDEDE DEGIL httpOnly cerezlere yazilir (`davet/parola` ve
 * `set-password` ile ayni kural): panelde JS jetonu ASLA gormez.
 *
 * `tesis_kodu` GOVDEDE DONER ve bu bir istisna degil, ucun isi: yonetici
 * o kodu sakinlerine/personeline iletecek ve SMS saglayicisi baglanana
 * kadar tek dagitim yolu ELLE iletmek (sartname §4). Kod bir SIR DEGIL —
 * zaten kamuya acik bir tanimlayici (goc 0037 guvenlik notu).
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/kayit/tesis-olustur",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    tesis_ad?: string;
    tesis_kodu?: string;
    jetonlar?: { access_token?: string; refresh_token?: string };
  };
  const access = govde.jetonlar?.access_token;
  const refresh = govde.jetonlar?.refresh_token;
  // Jeton eksikse cerez YAZILMAZ ve yanit oldugu gibi gecer: sessizce
  // "oturum acildi" demek, kullaniciyi her istekte 401 alacagi bir
  // panele sokmak olurdu.
  if (!access || !refresh) return yanit;
  return loginResponse(access, refresh, {
    tesis_ad: govde.tesis_ad,
    tesis_kodu: govde.tesis_kodu,
  });
}
