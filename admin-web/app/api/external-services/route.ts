import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.5) Dis hizmet/esnaf rehberi. Okuma tum roller, YAZMA yonetim. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/external-services", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/external-services", "POST", body);
}
