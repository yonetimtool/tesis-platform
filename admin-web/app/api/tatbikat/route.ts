import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P249 §2) Tatbikat listesi + planla. Yetki sunucuda (planlama yalniz yonetim).
export async function GET(): Promise<NextResponse> {
  return proxyJson("/tatbikat", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/tatbikat", "POST", body);
}
