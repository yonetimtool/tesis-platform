import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P163 §1) TOPLU GUNCELLEME VEKILI.
 *
 * BU YOL "KAZAYLA" CALISIYORDU: vekili yoktu ama `[id]` rotasinin
 * `PATCH`i devraliyor ve `/units/${id}` = `/units/toplu` kuruyordu —
 * dogru URL, yanlis sebep. `[id]` bir gun UUID dogrulamasi eklerse (ki
 * bu dosyayla birlikte EKLENDI) sessizce kirilirdi.
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units/toplu", "PATCH", body);
}
