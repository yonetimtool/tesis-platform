import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Kod dogru ise `setup_token` doner — OTURUM DEGIL. Cerez YAZILMAZ;
// oturum ancak parola belirlendikten sonra `/api/auth/set-password`te acilir.
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil("/auth/kayit/rol-dogrula", await req.json().catch(() => ({})));
}
