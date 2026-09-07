import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function POST(istek: Request, { params }: { params: { talep_id: string } }): Promise<NextResponse> {
  return backendeIlet(istek, `/dukkan/talep/${encodeURIComponent(params.talep_id)}/iptal`);
}
