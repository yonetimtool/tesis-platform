import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P154 / Asama 3) Rol + tesis ID + telefon -> eslesirse SMS kodu.
// Yanit AYNEN gecer: sunucu eslesme sonucunu BILEREK sizdirmiyor ve
// burada "bulunamadi" gibi bir metin uretmek o korumayi bozardi.
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil("/auth/kayit/rol-basla", await req.json().catch(() => ({})));
}
