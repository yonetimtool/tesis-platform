import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Self-servis parola degisimi — mevcut parola sunucuda dogrulanir. */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/password", "PATCH", body);
}
