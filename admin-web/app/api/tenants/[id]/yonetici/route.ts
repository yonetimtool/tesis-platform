import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// Yonetici ad/telefon/aktiflik guncelle (kismi). Telefon cakismasi -> 409.
export async function PATCH(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${id}/yonetici`, "PATCH", body);
}
