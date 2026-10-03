import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P253 §C-4) Toplu tahakkuk partisini ters kayitla geri al — sebep zorunlu
// (sunucu reddeder), admin+yonetici (backend RBAC zorlar).
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/borclandirma/parti/${params.id}/geri-al`, "POST", body);
}
