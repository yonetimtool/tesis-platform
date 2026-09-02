import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §4.2) Su an kim gorevde / sirada kim.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/vardiya-plani/simdi", "GET");
}
