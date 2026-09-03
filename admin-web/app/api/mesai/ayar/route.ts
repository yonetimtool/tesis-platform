import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P211 §5) Fazla mesai katsayisi — sutun P203'te acilmisti ama hicbir
// uctan yazilamiyordu. Yetki SUNUCUDA: yazma admin + yonetici.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/mesai/ayar", "GET");
}

export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/mesai/ayar", "PATCH", body);
}
