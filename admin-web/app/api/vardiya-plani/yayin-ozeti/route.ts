import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Yayin dugmesindeki sayi.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("baslangic", sp.get("baslangic") ?? "");
  qs.set("gun", sp.get("gun") ?? "7");
  return proxyJson(`/vardiya-plani/yayin-ozeti?${qs.toString()}`, "GET");
}
