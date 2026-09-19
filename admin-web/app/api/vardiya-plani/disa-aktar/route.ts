import { NextRequest, NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) XLSX indirme — IKILI vekil: `proxyJson` baytlari JSON diye
// ayristirmaya calisip dosyayi BOZARDI.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("baslangic", sp.get("baslangic") ?? "");
  qs.set("gun", sp.get("gun") ?? "7");
  return proxyBinary(`/vardiya-plani/disa-aktar?${qs.toString()}`, "GET");
}
