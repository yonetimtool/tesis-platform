import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §6) MEVCUT TESISE KATIL · SOSYAL yolu — 2. adim (e-posta OTP).
 *
 * Saglayici e-postayi dogrulamadiginda ilk adim `otp_gerekli` doner;
 * burada e-posta kodu dogrulanir. `durum=giris` ise jetonlar httpOnly
 * cerezlere yazilir ve govdeye KONMAZ; `onay_bekliyor` ise cerez yok.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/oauth/rol-tamamla-dogrula",
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
    return loginResponse(access, refresh, { durum: govde.durum });
  }
  return NextResponse.json(
    { durum: govde.durum, tesis_ad: govde.tesis_ad ?? null },
    { status: yanit.status },
  );
}
