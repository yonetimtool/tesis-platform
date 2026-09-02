import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P205 §2) ZAMAN CIZELGESI — kisi x saat.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  // BEYAZ LISTE (panel-vekil ile ayni kural): gelisiguzel parametre
  // gecirmek, backend'de olmayan bir suzgeci varmis gibi gosterirdi.
  qs.set("baslangic", sp.get("baslangic") ?? "");
  qs.set("gun", sp.get("gun") ?? "7");
  return proxyJson(`/vardiya-plani/cizelge?${qs.toString()}`, "GET");
}
