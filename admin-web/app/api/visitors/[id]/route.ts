import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P162) Ziyaretci kaydini duzenleme vekili — mobilde vardi, webde yoktu.
// Rol karari SUNUCUDA (`_REGISTRAR` = guvenlik); burada yalnizca iletim.
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/visitors/${params.id}`, "PATCH", body);
}
