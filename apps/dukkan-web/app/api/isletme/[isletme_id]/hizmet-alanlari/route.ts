import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts).
 */

export async function PUT(istek: Request, { params }: { params: { isletme_id: string } }): Promise<NextResponse> {
  return backendeIlet(istek, `/dukkan/isletme/${encodeURIComponent(params.isletme_id)}/hizmet-alanlari`);
}
