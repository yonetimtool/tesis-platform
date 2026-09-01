import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P192 §4.4) Sakinin MAKBUZ ARSIVI.
 *
 * Makbuz uretiliyordu ama sakin ONA ULASAMIYORDU: makbuz ucu yalniz
 * yonetime acikti ve arsiv ekrani yoktu. Odedigi paranin belgesine
 * erisemeyen sakin, her seferinde yonetime sormak zorunda kalirdi.
 *
 * Kapsam SUNUCUDA daraltilir (`GET /me/makbuzlar` yalniz kullanicinin
 * kendi makbuzlarini doner); vekil yalnizca sayfalama parametrelerini
 * iletir.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  for (const ad of ["limit", "offset"]) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  const sorgu = qs.toString();
  return proxyJson(sorgu ? `/me/makbuzlar?${sorgu}` : "/me/makbuzlar", "GET");
}
