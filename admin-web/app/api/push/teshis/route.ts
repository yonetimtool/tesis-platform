import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191 §2) Push zincirinin durum tablosu + son denemeler.
 *
 * `limit` DISINDAKI parametreler ILETILMEZ: BFF'te sorgu dizesini oldugu
 * gibi gecirmek, arka uctaki her yeni parametreyi sessizce disariya acmak
 * demektir (depo deseni).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const limit = req.nextUrl.searchParams.get("limit") ?? "50";
  return proxyJson(`/push/teshis?limit=${encodeURIComponent(limit)}`, "GET");
}
