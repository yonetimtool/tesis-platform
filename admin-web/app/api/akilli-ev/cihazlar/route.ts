import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §3) Cihaz listesi + ekleme. Sunucu, sakini KENDI dairesine
// kisitlar; panel bu kisiti TEKRARLAMAZ (tek dogruluk kaynagi sunucu).
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/akilli-ev/cihazlar${req.nextUrl.search}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/akilli-ev/cihazlar", "POST", body);
}
