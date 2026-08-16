import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P163 §1) KAT SILME VEKILI — `bulk` ile AYNI 405 hatasi.
 *
 * Tarama sirasinda bulundu: bu da `POST` istiyordu, `[id]`de `POST` yoktu.
 * Yani bildirilen tek hatanin ikizi vardi ve henuz kimse denememisti.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units/kat-sil", "POST", body);
}
