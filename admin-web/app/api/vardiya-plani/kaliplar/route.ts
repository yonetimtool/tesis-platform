import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P207 §1) Vardiya kaliplari — gunu N vardiyaya bolme sablonu.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/vardiya-plani/kaliplar", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/vardiya-plani/kaliplar", "POST", body);
}
