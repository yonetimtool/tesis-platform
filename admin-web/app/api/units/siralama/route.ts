import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P163 §1) SIRALAMA VEKILI — `bulk` ile ayni sinif; bkz. `bulk/route.ts`. */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units/siralama", "PATCH", body);
}
