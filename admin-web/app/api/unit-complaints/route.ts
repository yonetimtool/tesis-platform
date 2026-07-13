import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// GET /unit-complaints?target_unit_id=&durum= — bir dairenin ANONIM sikayet
// listesi (kategori + tarih; notlar YALNIZ admin/yonetici icin dolu). complainant
// ASLA donmez (sunucu zorlar).
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  const targetUnitId = sp.get("target_unit_id");
  if (targetUnitId) qs.set("target_unit_id", targetUnitId);
  const durum = sp.get("durum");
  if (durum) qs.set("durum", durum);
  qs.set("limit", sp.get("limit") ?? "200");
  return proxyJson(`/unit-complaints?${qs.toString()}`, "GET");
}
