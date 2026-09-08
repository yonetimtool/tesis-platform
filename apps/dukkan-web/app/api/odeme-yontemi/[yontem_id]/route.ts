import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function DELETE(
  istek: Request,
  { params }: { params: Promise<{ yontem_id: string }> },
): Promise<NextResponse> {
  const { yontem_id } = await params;
  return backendeIlet(istek, `/dukkan/odeme-yontemi/${yontem_id}`);
}
