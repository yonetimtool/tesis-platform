import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P250 §6) `GET/PUT /api/me/hizli-islemler` — Ozet sayfasindaki "Hizli
 * Islemler" kartinin secimi. HESAPTA durur (`pano_tercihi.hizli_islemler`),
 * mobil ayni uctan okur. Secenekler ROLE gore sunucudan gelir.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/hizli-islemler", "GET");
}

export async function PUT(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/hizli-islemler", "PUT", body);
}
