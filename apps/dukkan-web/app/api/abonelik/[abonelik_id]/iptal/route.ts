import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts). */
export async function POST(
  istek: Request,
  { params }: { params: Promise<{ abonelik_id: string }> },
): Promise<NextResponse> {
  const { abonelik_id } = await params;
  return backendeIlet(istek, `/dukkan/abonelik/${abonelik_id}/iptal`);
}
