import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §6) MEVCUT TESISE KATIL · SOSYAL yolu — 1. adim (SMS'siz).
 *
 * `durum=giris`   -> kimlik baglandi, jetonlar httpOnly cerezlere yazilir
 *                    ve govdeye KONMAZ (parolali giris yolunun kurali).
 * `durum=otp_gerekli` / `onay_bekliyor` -> cerez yok; yanit aynen gecer.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/oauth/rol-tamamla",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    durum?: string;
    tesis_ad?: string | null;
    jetonlar?: { access_token?: string; refresh_token?: string } | null;
  };
  const access = govde.jetonlar?.access_token;
  const refresh = govde.jetonlar?.refresh_token;
  if (govde.durum === "giris" && access && refresh) {
    // Oturum acildi. `durum` govdede DE tutulur ki istemci akisi ayni
    // yaniti "giris" olarak cozup koke gitsin.
    return loginResponse(access, refresh, { durum: govde.durum });
  }
  // Jetonlari (varsa) govdeden ELE: sosyal giris cerezi burada yazilir,
  // JS'e jeton sizmaz.
  return NextResponse.json(
    { durum: govde.durum, tesis_ad: govde.tesis_ad ?? null },
    { status: yanit.status },
  );
}
