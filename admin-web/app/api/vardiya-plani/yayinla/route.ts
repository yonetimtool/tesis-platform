import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Donemin taslak/degismis satirlarini yayinla.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("baslangic", sp.get("baslangic") ?? "");
  qs.set("gun", sp.get("gun") ?? "7");
  return proxyJson(`/vardiya-plani/yayinla?${qs.toString()}`, "POST", {});
}
