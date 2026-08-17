import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) Self-servis profil fotografi.
 *
 * Dosyanin KENDISI buradan GECMEZ: tarayici `/api/uploads` ile aldigi
 * presigned URL'e dogrudan PUT eder ve BURAYA yalnizca obje anahtarini
 * gonderir (duyuru gorseliyle ayni akis). Anahtarin kendi tenant
 * namespace'inde oldugu SUNUCUDA dogrulanir — IDOR engeli orada.
 *
 * `avatar_key: null` fotografi kaldirir ve eski obje MinIO'dan silinir.
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/avatar", "PATCH", body);
}
