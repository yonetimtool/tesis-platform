import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.4) Ziyaretci kayitlari. KAYIT yalniz guvenlik (sunucu zorlar).
 *
 * (P245) DORT SUZGEC BURADA DUSUYORDU.
 *
 * Arka uc `icerde`, `unit_id`, `baslangic` ve `bitis`i destekliyor
 * (`list_visitors`) ama vekil yalniz `limit`/`offset` tasiyordu. Yani
 * ekran "icerideki ziyaretciler" diye suzemiyordu — ki bu, kapidaki
 * gorevlinin en sik sordugu soru.
 *
 * Ayni kusur sinifinin ALTINCI ornegi (P173, P189, P213 + P244 §6/§8a/
 * §8c + P245 §3). Vekil GORUNMEZ oldugu icin sessizce yanlis olur.
 */
const SUZGECLER = ["icerde", "unit_id", "baslangic", "bitis"] as const;

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  for (const ad of SUZGECLER) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  return proxyJson(`/visitors?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/visitors", "POST", body);
}
