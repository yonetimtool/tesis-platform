import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P211 §1) COK TESISLI YONETICI — SSO'da tesis secimi.
 *
 * Backend `durum=giris` + jetonlar doner; jetonlar GOVDEDE GECMEZ,
 * httpOnly cerezlere yazilir (rol-tamamla yolunun ayni kurali).
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/oauth/tesis-sec",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    durum?: string;
    jetonlar?: { access_token?: string; refresh_token?: string } | null;
  };
  const access = govde.jetonlar?.access_token;
  const refresh = govde.jetonlar?.refresh_token;
  if (govde.durum === "giris" && access && refresh) {
    return loginResponse(access, refresh, { durum: govde.durum });
  }
  return NextResponse.json({ durum: govde.durum }, { status: yanit.status });
}
