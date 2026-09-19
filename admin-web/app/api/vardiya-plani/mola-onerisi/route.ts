import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) 4857 md. 68 — onerilen ara dinlenme.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("baslangic_saat", sp.get("baslangic_saat") ?? "");
  qs.set("bitis_saat", sp.get("bitis_saat") ?? "");
  return proxyJson(`/vardiya-plani/mola-onerisi?${qs.toString()}`, "GET");
}
