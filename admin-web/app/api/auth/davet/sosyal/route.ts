import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P155 §7) Davetle gelen kullanici SOSYAL hesabini baglar (SMS yok). */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil("/davet/sosyal", await req.json().catch(() => ({})));
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    access_token?: string;
    refresh_token?: string;
  };
  if (!govde.access_token || !govde.refresh_token) return yanit;
  return loginResponse(govde.access_token, govde.refresh_token);
}
