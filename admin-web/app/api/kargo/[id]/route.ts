import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
// Kimlik UUID OLMALI: tek segment olsa da yol parcasini dogrulamadan
// gecirmemek (panel vekiliyle ayni savunma).
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// (P189) BFF EKSIK ROTA (P173 sinifi): kargolar sayfasi PATCH /api/kargo/{id}
// (teslim isaretleme) cagiriyordu ama bu dosya yoktu -> 405. Backend'de
// PATCH /kargo/{kargo_id} ZATEN var; eksik olan yalnizca BFF vekiliydi.
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/kargo/${params.id}`, "PATCH", body);
}
