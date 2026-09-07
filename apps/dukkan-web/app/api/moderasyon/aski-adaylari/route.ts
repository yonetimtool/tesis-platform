import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function GET(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/moderasyon/aski-adaylari");
}
