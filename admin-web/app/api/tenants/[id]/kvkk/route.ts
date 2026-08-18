import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// (P170 §2) KVKK VE YASAL METIN YONETIMI — PLATFORM YOLU.
//
// Eskiden `/api/panel/kvkk-metinler` (okuma) ve `/api/panel/kvkk-metin`
// (yazma) vardi; ikisi de CAGIRANIN KENDI tenant'ina gidiyordu ve tesis
// yuzeyindeydi. Artik hedef tenant YOLDA tasiniyor: platform yoneticisi
// hangi tesise yayin yaptigini SECER.
//
// YETKI SUNUCUDA: bu vekil yalniz istegi tasir. `/tenants/*` uclarinin
// tamami backend'de `require_role("admin")` arkasindadir — kapiyi burada
// kurmak, ikinci ve unutulmaya acik bir kopya olurdu.
export async function GET(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}/kvkk`, "GET");
}

export async function POST(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${id}/kvkk`, "POST", body);
}
