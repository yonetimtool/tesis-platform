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
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/vehicle-passes?${qs.toString()}`, "GET");
}
