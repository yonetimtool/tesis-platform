import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P193 §6) ARSA PAYI TOPLU YAZMA VEKILI — `PATCH /api/units/arsa-payi`.
 *
 * AYRI DOSYA SART: `[id]` rotasi UUID dogrulamasi yapiyor (bkz. `toplu`
 * vekilinin basligi) ve "arsa-payi" bir UUID DEGIL — istek panelden hic
 * cikmadan 404 alirdi. Duragan segment dinamigi yener; dosyanin varligi
 * bir karardir, kopya degil.
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units/arsa-payi", "PATCH", body);
}
