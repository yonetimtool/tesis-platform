import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §1) Gecmis bakim kayitlari.
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/bakim/kayitlar${req.nextUrl.search}`, "GET");
}
