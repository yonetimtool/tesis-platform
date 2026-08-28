import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §6) MEVCUT TESISE KATIL · PAROLA yolu — 1. adim.
 *
 * Tesis ID + e-posta + rol -> e-postaya 6 haneli kod. Yanit AYNEN gecer:
 * arka uc e-postanin listede olup olmadigini BILEREK sizdirmiyor
 * (`tesis_ad` doner cunku kod zaten kamuya acik) ve burada bir
 * "bulunamadi" metni uretmek o korumayi bozardi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil(
    "/auth/kayit/rol-eposta-basla",
    await req.json().catch(() => ({})),
  );
}
