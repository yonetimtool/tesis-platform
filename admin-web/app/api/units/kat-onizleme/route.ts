import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P165) KAT SILME ETKI OZETI vekili.
 *
 * DUZ SEGMENT: `[id]` rotasina dusmesin diye kendi dosyasinda — P163'te
 * olculen 405 sinifinin ayni tuzagi (bkz. `tests/bff-yol-eslesmesi.test.ts`).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    blok: sp.get("blok") ?? "",
    kat: sp.get("kat") ?? "",
  });
  return proxyJson(`/units/kat-onizleme?${qs.toString()}`, "GET");
}
