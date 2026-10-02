import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P251 §10) Platform gonderim gunlugu — YALNIZ admin (backend RBAC zorlar).
// Sorgu BEYAZ LISTEYLE tasinir (P226 dersi: ham yeniden yayin, ileride
// eklenen bir parametreyi farkinda olmadan acmak olurdu).
const IZINLI = ["kanal", "tenant_id", "durum", "ara", "from", "to", "basarisiz"] as const;

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "50");
  qs.set("offset", sp.get("offset") ?? "0");
  for (const k of IZINLI) {
    const v = sp.get(k);
    if (v) qs.set(k, v);
  }
  return proxyJson(`/platform/gonderim-gunlugu?${qs.toString()}`, "GET");
}
