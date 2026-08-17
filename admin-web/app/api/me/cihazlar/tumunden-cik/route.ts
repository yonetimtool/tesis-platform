import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) "Tumunden cik" — butun cihazlari pasiflestirir.
 *
 * DUZ SEGMENT, `[id]`nin ONUNDE cozulur (Next kurali) — bu yuzden ayri
 * dosya sart: `[id]` rotasi POST tanimlamiyor ve istek 405'e duserdi
 * (P163'te `units/bulk` ile yasanan hata sinifi).
 */
export async function POST(): Promise<NextResponse> {
  return proxyJson("/me/cihazlar/tumunden-cik", "POST", {});
}
