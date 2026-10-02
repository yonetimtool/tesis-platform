import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P251 §8) GORUNTULEME IZNI — web'e eklendi (mobilde vardi).
 * Liste + tek daire talebi. Rol kapisi sunucuda (`unit_access.py`:
 * talep = admin, yonetici).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/unit-access-request?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/unit-access-request", "POST", body);
}
