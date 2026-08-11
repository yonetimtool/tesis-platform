import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// SMS kodu dogruysa kimlik baglanir VE oturum acilir. Jetonlar cereze
// yazilir, govdede DONMEZ (bkz. `oturum-kapisi`).
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/oauth/baglan/dogrula",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    access_token?: string;
    refresh_token?: string;
  };
  if (!govde.access_token || !govde.refresh_token) return NextResponse.json(govde);
  return oturumAc(req, govde.access_token, govde.refresh_token);
}
