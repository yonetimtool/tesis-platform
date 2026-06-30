import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const baslangic = sp.get("baslangic");
  if (baslangic) qs.set("baslangic", baslangic);
  const bitis = sp.get("bitis");
  if (bitis) qs.set("bitis", bitis);
  const durum = sp.get("durum");
  if (durum === "bekliyor" || durum === "tamamlandi" || durum === "kacirildi") qs.set("durum", durum);
  const planId = sp.get("patrol_plan_id");
  if (planId) qs.set("patrol_plan_id", planId);
  return proxyJson(`/patrol-windows?${qs.toString()}`, "GET");
}
