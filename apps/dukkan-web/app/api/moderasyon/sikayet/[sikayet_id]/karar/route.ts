import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function POST(istek: Request, { params }: { params: { sikayet_id: string } }): Promise<NextResponse> {
  return backendeIlet(istek, `/dukkan/moderasyon/sikayet/${encodeURIComponent(params.sikayet_id)}/karar`);
}
