import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P191 §4) Hareket listesi. YALNIZ bilinen suzgecler iletilir. */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "50");
  qs.set("offset", sp.get("offset") ?? "0");
  const durum = sp.get("durum");
  if (durum) qs.set("durum", durum);
  return proxyJson(`/banka/hareketler?${qs.toString()}`, "GET");
}
