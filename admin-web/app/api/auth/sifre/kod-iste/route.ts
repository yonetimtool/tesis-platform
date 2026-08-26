import { NextRequest, NextResponse } from "next/server";

import { backendGiris } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P181 Bölüm 2) ŞİFREMİ UNUTTUM — sıfırlama kodu iste. Public (pre-auth):
// oturum çerezi taşınmaz, jeton üretmez. Yanıt sızıntısız (her durumda aynı).
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return backendGiris("/auth/sifre/kod-iste", body, false);
}
