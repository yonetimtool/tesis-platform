import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P167 Asama 2) Kisisel takvim notlari — kayit YALNIZ sahibinindir. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/hatirlatmalar", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/hatirlatmalar", "POST", body);
}
