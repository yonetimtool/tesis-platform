import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P247 §1) Etkin/sonlanmis dongu atamalari.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/vardiya-plani/dongu-atamalari", "GET");
}
