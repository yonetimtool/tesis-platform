import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Bina blok CRUD (D-viz Rev-2 gorsel editor) — backend /blocks'a proxy.
// RBAC backend'de admin+yonetici; panel oturumu admin-only (login gate).
export async function GET(): Promise<NextResponse> {
  return proxyJson("/blocks", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/blocks", "POST", body);
}
