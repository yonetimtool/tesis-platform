import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P250 §2) `POST /api/users/odeme-kodlari/eposta` — odeme kodunu tek
 * kisiye ya da secilenlere e-postayla gonderir.
 *
 * AYRI DOSYA SART (ust klasordeki `odeme-kodlari/route.ts` ile ayni
 * gerekce): `users/[id]/...` dinamik segmenti bu yolu yakalamasin.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/users/odeme-kodlari/eposta", "POST", body);
}
