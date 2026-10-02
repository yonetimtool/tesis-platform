import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// (P250 §8) Secilen tesisin ayarlariyla GERCEK test gonderimi.
export async function POST(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${encodeURIComponent(id)}/mesaj-ayarlari/test`, "POST", body);
}
