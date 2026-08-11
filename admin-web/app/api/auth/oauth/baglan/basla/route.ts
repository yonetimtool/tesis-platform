import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Yanit AYNEN gecer: sunucu eslesme sonucunu BILEREK sizdirmiyor ve
// burada "bulunamadi" gibi bir metin uretmek o korumayi bozardi.
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil("/auth/oauth/baglan/basla", await req.json().catch(() => ({})));
}
