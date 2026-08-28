import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §2) YENI TESIS · PAROLA yolu — 2. adim.
 *
 * E-posta kodu dogruysa KURULUM JETONU doner (oturum DEGIL). Jeton
 * govdede gecer: bir sonraki adim (`yonetici-tesis`) onunla acilir ve
 * yalniz kisa omurlu, tek adimlik bir yetkidir — oturum cerezi degil.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil(
    "/auth/kayit/yonetici-dogrula",
    await req.json().catch(() => ({})),
  );
}
