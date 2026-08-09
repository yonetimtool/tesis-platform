import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P154 / Asama 3) Parola belirleme — kaydin SON adimi.
 *
 * Sunucu tam bir token cifti doner; onu govdede istemciye vermek yerine
 * `loginResponse` ile httpOnly cerezlere yaziyoruz. Panelde jeton HICBIR
 * ZAMAN JS'e gorunmez (mevcut giris yollarinin aynisi); govdede dondurmek
 * o kurali yalniz bu ekran icin delerdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/set-password",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    access_token?: string;
    refresh_token?: string;
  };
  if (!govde.access_token || !govde.refresh_token) return yanit;
  return loginResponse(govde.access_token, govde.refresh_token);
}
