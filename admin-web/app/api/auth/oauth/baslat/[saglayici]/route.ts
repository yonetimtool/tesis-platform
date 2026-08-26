import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, istemciIp } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P154 / Asama 4) Saglayiciya gidilecek adresi uretir.
//
// SAGLAYICI ADI DOGRUDAN YOLA GIRMEZ gibi gorunse de girer — bu yuzden
// arka uc onu KAPALI BIR KUME ile karsilar (`saglayici_al` -> 404).
// Burada ikinci bir beyaz liste tutmak, iki yerde iki farkli kume
// bulundurma riski demekti.
export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ saglayici: string }> },
): Promise<NextResponse> {
  const { saglayici } = await ctx.params;
  // (P180) niyet=kayit onaylarinin IP'si icin gercek istemci adresini gecir.
  const ip = istemciIp(req.headers);
  return anonimVekil(
    `/auth/oauth/baslat/${encodeURIComponent(saglayici)}`,
    await req.json().catch(() => ({})),
    ip ? { "x-istemci-ip": ip } : undefined,
  );
}
