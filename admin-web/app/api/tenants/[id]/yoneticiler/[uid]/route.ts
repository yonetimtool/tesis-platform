import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string; uid: string }> };

// (P154) Yoneticiyi tesisten cikarir. Uc ayri 409 uretebilir (son yonetici /
// birincil / kayitlari var) ve UCUNUN DE metni farklidir — arayuz metni
// AYNEN gosterir, kendi cumlesini uydurmaz.
export async function DELETE(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id, uid } = await ctx.params;
  return proxyJson(`/tenants/${id}/yoneticiler/${uid}`, "DELETE");
}
