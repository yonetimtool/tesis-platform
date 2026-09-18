import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §3) Dokuz bolumun anahtarlari.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/akilli-ev/bolumler", "GET");
}

export async function PUT(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/akilli-ev/bolumler", "PUT", body);
}
