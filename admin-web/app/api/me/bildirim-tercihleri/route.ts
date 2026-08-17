import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) Bildirim kanali tercihleri — e-posta / SMS / mobil.
 *
 * `/api/me/pazarlama` ile KARISTIRILMAMALI: orasi bir KVKK rizasi
 * (varsayilani kapali), burasi bir kullanim tercihi (varsayilani acik).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/bildirim-tercihleri", "GET");
}

export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/bildirim-tercihleri", "PATCH", body);
}
