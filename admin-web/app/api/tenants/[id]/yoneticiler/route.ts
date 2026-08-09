import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// (P154) Tesisin TUM yoneticileri. Tekil `/yonetici` yolu BIRINCIL'i
// hedefler ve OLDUGU GIBI durur; bu cogul yol coklu yonetim icindir.
export async function GET(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}/yoneticiler`, "GET");
}

// Var olan tesise SONRADAN yonetici ekle; tek seferlik gecici kod doner.
export async function POST(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${id}/yoneticiler`, "POST", body);
}
