import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Destek kanali (WP1) — YALNIZ admin (backend RBAC zorlar). TUM tenant'larin
// biletleri backend SECURITY DEFINER `support_ticket_list` ile.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "50");
  qs.set("offset", sp.get("offset") ?? "0");
  for (const k of ["tenant_id", "durum"]) {
    const v = sp.get(k);
    if (v) qs.set(k, v);
  }
  return proxyJson(`/support/all?${qs.toString()}`, "GET");
}
