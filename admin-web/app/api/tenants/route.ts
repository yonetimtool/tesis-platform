import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Platform admini: tum tesisleri listeler (cross-tenant). Backend
// require_role("admin") + list_all_tenants() SECURITY DEFINER ile calisir.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/tenants", "GET");
}

// Yeni tesis (isimsiz) + yoneticisini acar. Parola bossa gecici kod doner.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/tenants", "POST", body);
}
