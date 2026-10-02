import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// (P250 §8) Secilen tesisin TEKNIK mesaj ayarlari (saglayici, SMTP, kota).
// Yalniz platform admini (backend RBAC); tesis yoneticisi bunlari GORMEZ.
export async function GET(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${encodeURIComponent(id)}/mesaj-ayarlari`, "GET");
}

export async function PUT(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${encodeURIComponent(id)}/mesaj-ayarlari`, "PUT", body);
}
