import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P193 §6) ARSA PAYI OZETI — `GET /api/units/arsa-payi-ozeti`.
 *
 * Toplam AYRI BIR UCTAN gelir: daire listesi sayfalidir ve gorunen 25
 * satirin toplami "toplam arsa payi" DEGILDIR. Yanlis bir toplam, dogru
 * gorunen bir hatadir.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/units/arsa-payi-ozeti", "GET");
}
