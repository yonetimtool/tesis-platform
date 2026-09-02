import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §4) Haftalik plan izgarasi.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  // BEYAZ LISTE: gelisiguzel parametre gecirmek, backend'de olmayan bir
  // suzgeci varmis gibi gostermek olurdu (panel-vekil ile ayni kural).
  qs.set("baslangic", sp.get("baslangic") ?? "");
  qs.set("gun", sp.get("gun") ?? "7");
  return proxyJson(`/vardiya-plani?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/vardiya-plani", "POST", body);
}
