import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Rezervasyon yapilabilir ortak alanlar — LISTE (tum roller okur). */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/common-areas?limit=100&offset=0", "GET");
}

// (P181 Bölüm 9) ALAN OLUSTUR — yalniz yonetim (backend `_MANAGER` kapisi
// zorlar; ad benzersizligi + saat tutarliligi da SUNUCUDA).
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/common-areas", "POST", body);
}
