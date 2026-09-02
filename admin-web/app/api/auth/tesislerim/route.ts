import { NextRequest, NextResponse } from "next/server";

import { backendGiris } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §2) Giris ONCESI: bu kimlik hangi tesislerde gecerli.
// Oturum cerezi TASIMAZ (kullanicinin henuz oturumu yok) ve jeton
// URETMEZ — yalnizca liste doner.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const govde = await req.json().catch(() => ({}));
  return backendGiris("/auth/tesislerim", govde, false);
}
