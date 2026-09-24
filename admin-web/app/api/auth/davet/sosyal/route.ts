import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

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
  // (E2E 2026-09) Rol kapisi — bkz. davet/parola.
  return oturumAc(req, govde.access_token, govde.refresh_token);
}
