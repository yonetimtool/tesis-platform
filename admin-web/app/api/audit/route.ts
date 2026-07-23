import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Denetim kaydi (WP1) — YALNIZ admin (backend RBAC zorlar). Filtreleri backend
// GET /audit'e iletir; capraz-tenant okuma backend SECURITY DEFINER ile.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "50");
  qs.set("offset", sp.get("offset") ?? "0");
  for (const k of ["tenant_id", "action", "resource_type", "from", "to"]) {
    const v = sp.get(k);
    if (v) qs.set(k, v);
  }
  return proxyJson(`/audit?${qs.toString()}`, "GET");
}
