import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P252 §3) Personel detayi — `user_id` ya da `kart_id` (beyaz liste). */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  for (const ad of ["user_id", "kart_id"]) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  return proxyJson(`/personel/detay?${qs.toString()}`, "GET");
}
