import { NextRequest, NextResponse } from "next/server";

import { anonimVekil, istemciIp } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P185 §2) YENI TESIS · PAROLA yolu — 1. adim.
 *
 * Basvuruyu yazar ve e-postaya 6 haneli kod gonderir. Yanit oturum
 * ACMAZ (henuz tesis/kullanici yok) — cerez YAZILMAZ. IP basliktan
 * gecirilir: onay kaydinin ispat degeri icin (arka uc `X-Istemci-Ip`
 * okur; tarayici kendi IP'sini bilemez).
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const ip = istemciIp(req.headers);
  return anonimVekil(
    "/auth/kayit/yonetici-basvuru",
    await req.json().catch(() => ({})),
    ip ? { "x-istemci-ip": ip } : undefined,
  );
}
