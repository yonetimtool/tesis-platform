import { NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Ornek sablon — ikili vekil.
export async function GET(): Promise<NextResponse> {
  return proxyBinary("/vardiya-plani/ornek-sablon", "GET");
}
