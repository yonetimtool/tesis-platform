import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §3) Olay -> cihaz eylemi senaryolari.
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/akilli-ev/senaryolar${req.nextUrl.search}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/akilli-ev/senaryolar", "POST", body);
}
