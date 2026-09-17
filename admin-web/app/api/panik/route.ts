import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §1) PANIK — liste + tetikleme.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const qs = req.nextUrl.search;
  return proxyJson(`/panik${qs}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/panik", "POST", body);
}
