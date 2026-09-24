import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  const limit = sp.get("limit") ?? "20";
  const offset = sp.get("offset") ?? "0";
  qs.set("limit", limit);
  qs.set("offset", offset);
  const okundu = sp.get("okundu");
  if (okundu === "true" || okundu === "false") qs.set("okundu", okundu);
  // (E2E 2026-09) ARAMA TASINMIYORDU: sayfa `q` gonderiyor, vekil onu
  // beyaz listede tutmadigi icin backend'e hic gitmiyordu — iki sekmede de
  // arama kutusu hicbir seyi suzmuyordu (mobil ayni ucu `q` ile kullanir).
  const q = sp.get("q")?.trim();
  if (q) qs.set("q", q.slice(0, 100));
  return proxyJson(`/notifications?${qs.toString()}`, "GET");
}
