import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §1) Yillik bakim ozeti — denetime verilebilir.
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/bakim/ozet${req.nextUrl.search}`, "GET");
}
