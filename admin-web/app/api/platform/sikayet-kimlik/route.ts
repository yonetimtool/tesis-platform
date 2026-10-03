import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P253 §D) RESMI KIMLIK ACMA — YALNIZ platform admin (backend RBAC zorlar).
// Gerekce govdede; her goruntuleme o tesisin denetimine yazilir.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/platform/sikayet-kimlik", "POST", body);
}
