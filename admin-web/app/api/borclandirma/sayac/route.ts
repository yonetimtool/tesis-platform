import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P111) Sayac okuma sihirbazinin SON adimi — TEK istek.
 *
 * Sunucunun sozlesmesi (`SayacBorcIstek` docstring) acikca soyle der: ilk uc
 * adim ISTEMCIDE toplanir, sunucuya tek istek gelir. Ara adimlar icin vekil
 * uc ACILMAZ — sunucuda yarim sihirbaz durumu tutmak, o durumu temizlemek
 * zorunda birakirdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/borclandirma/sayac", "POST", body);
}
