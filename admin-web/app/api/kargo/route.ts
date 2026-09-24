import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.4) Kargo/teslimat kayitlari.
 *
 * (P244 §8a) SUZGECLER ILETILIR — BEYAZ LISTEYLE.
 *
 * Vekil yalniz `limit`/`offset` tasiyordu; sayfadaki durum suzgeci ve
 * ozet sayaclari sunucuya HIC ulasmazdi ve liste suzulmemis donerdi.
 * Bu, depoda tekrar eden bir kusur sinifidir (P173/P189/P213): vekil
 * parametreyi SESSIZCE dusurur, ekran "suzdum" sanir.
 *
 * Beyaz liste, `?` ile gelen her seyi gecirmemek icin: uce yalnizca
 * SOZLESMEDE tarif edilen alanlar gider.
 */
// (P247 §3) `gecikmis` — 3 gunden eski bekleyen kargolar (sunucu hesaplar).
const SUZGECLER = ["durum", "gecikmis", "unit_id", "baslangic", "bitis"] as const;

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
  return proxyJson(`/kargo?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/kargo", "POST", body);
}
