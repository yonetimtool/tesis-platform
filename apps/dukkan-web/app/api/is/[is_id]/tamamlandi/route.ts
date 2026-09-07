import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function POST(istek: Request, { params }: { params: { is_id: string } }): Promise<NextResponse> {
  return backendeIlet(istek, `/dukkan/is/${encodeURIComponent(params.is_id)}/tamamlandi`);
}
