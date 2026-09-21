import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.4) Olay/ihlal bildirimleri.
 *
 * (P245) `durum` SUZGECI BURADA DUSUYORDU.
 *
 * Arka uc `durum`u destekliyor (`list_violations`: ViolationDurum) ama
 * vekil yalniz `limit`/`offset` tasiyordu — yani ekran bir durum
 * suzgeci sunsaydi SESSIZCE calismazdi.
 *
 * Depoda ayni kusur sinifinin BESINCI ornegi: P173, P189, P213 ve
 * P244'te §6 (araç geçişleri), §8a (kargo), §8c (görevler). Bu kadar
 * tekrar edince artik kaza degil: vekil GORUNMEZ oldugu icin sessizce
 * yanlis olur. `p244-*-bff-suzgec` dosyalari bu yuzden var.
 */
const SUZGECLER = ["durum"] as const;

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
  return proxyJson(`/violations?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/violations", "POST", body);
}
