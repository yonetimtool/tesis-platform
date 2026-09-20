import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.4) Arac gecis kayitlari — SALT OKUMA.
 *
 * Kayitlar ANPR ile otomatik olusur (P16); elle giris ucu bilerek
 * acilmadi: plaka kaydini elle yazmak, otomatik kayitla celisen ikinci bir
 * gercek uretirdi.
 */
/**
 * (P244 §6) SUZGECLER TASINIYOR — OLCULEN EKSIK.
 *
 * Sunucu `acik`, `plaka`, `baslangic` ve `bitis` suzgeclerini P16'dan
 * beri destekliyor ve sozlesme bunlari ACIKCA sayac tarifi olarak
 * belgeliyor ("Ana ekran sayaci: `?acik=true&limit=1` -> `meta.total`").
 * BFF rotasi ise YALNIZ `limit`/`offset` tasiyordu — yani web ne plakaya
 * gore arayabiliyor ne de "iceride kac arac var" sorabiliyordu.
 *
 * Depoda kayitli sinif (P213): BFF sorgu suzgecini BEYAZ LISTEYLE tasir.
 * Beyaz liste, istemcinin uydurdugu bir parametrenin sunucuya
 * sizmamasini saglar; `req.nextUrl.search`i oldugu gibi iletmek o
 * guvenceyi kaldirirdi.
 */
const SUZGECLER = ["acik", "plaka", "baslangic", "bitis"] as const;

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  for (const ad of SUZGECLER) {
    const v = sp.get(ad);
    if (v !== null && v !== "") qs.set(ad, v);
  }
  return proxyJson(`/vehicle-passes?${qs.toString()}`, "GET");
}
