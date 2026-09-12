import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

/** (P224) Arsivden geri getir. */
export async function POST(
  _req: NextRequest,
  ctx: Ctx,
): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}/geri-al`, "POST", {});
}
