import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// Tesis detayi (tenant + yoneticisi). Admin-only (backend RBAC).
export async function GET(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}`, "GET");
}

// Tesisi + TUM verisini siler (cascade, geri alinamaz).
export async function DELETE(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}`, "DELETE");
}
