import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { setSorgusu } from "@/lib/egitim-bff";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P250 §4) `GET /api/egitim-videolari` — kurulum egitim videolari +
 * izlendi bilgisi. Yalniz `set` sorgusu tasinir (beyaz liste; bkz.
 * `bff-yol-eslesmesi` dersleri): bilinmeyen parametre backend'e sizmaz.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/egitim-videolari${setSorgusu(req)}`, "GET");
}
