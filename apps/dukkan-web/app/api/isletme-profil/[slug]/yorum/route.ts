import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function GET(istek: Request, { params }: { params: { slug: string } }): Promise<NextResponse> {
  return backendeIlet(istek, `/dukkan/isletme-profil/${encodeURIComponent(params.slug)}/yorum`);
}
