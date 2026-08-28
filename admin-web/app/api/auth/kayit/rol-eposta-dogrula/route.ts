import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §6) MEVCUT TESISE KATIL · PAROLA yolu — 2. adim.
 *
 * Kod dogruysa `durum=hazir` + `setup_token` (parola belirleme jetonu)
 * doner; liste disi/rol uyusmuyorsa `durum=onay_bekliyor` doner. Yanit
 * AYNEN gecer — oturum bu adimda ACILMAZ (parola `set-password` ile
 * ayrica belirlenir), dolayisiyla cerez YAZILMAZ.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil(
    "/auth/kayit/rol-eposta-dogrula",
    await req.json().catch(() => ({})),
  );
}
