import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §2) YENI TESIS · PAROLA yolu — 3. adim.
 *
 * Tesisi acar ve oturumu ACAR. Jetonlar GOVDEDE DEGIL httpOnly cerezlere
 * yazilir (`tesis-olustur` ile ayni kural); `tesis_kodu` govdede DONER
 * cunku yonetici onu sakinlerine/personeline iletecek (kamuya acik bir
 * tanimlayici, sir degil).
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/kayit/yonetici-tesis",
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
  if (!access || !refresh) return NextResponse.json(govde, { status: yanit.status });
  return loginResponse(access, refresh, {
    tesis_ad: govde.tesis_ad,
    tesis_kodu: govde.tesis_kodu,
  });
}
