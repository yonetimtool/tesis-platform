import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Rezervasyonlar.
 *
 * LISTE SUNUCUDA KENDI-KAPSAMLIDIR: sakin yalniz kendi rezervasyonlarini
 * gorur. Istemci suzgeci KOYULMADI — bir gun unutulur, sunucu kurali
 * unutulmaz (`taleplerim` ile ayni gerekce).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/reservations?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  // ZAMANLAMA KURALLARI (24 sa / gunde bir / 10 dk) SUNUCUDA olculur ve
  // hata metni istegin dilinde doner. BFF'te ikinci bir kopya, iki kuralin
  // zamanla ayrismasi demekti.
  return proxyJson("/reservations", "POST", body);
}
