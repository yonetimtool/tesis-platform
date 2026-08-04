import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Rezervasyon yapilabilir ortak alanlar — SALT OKUMA. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/common-areas?limit=100&offset=0", "GET");
}
