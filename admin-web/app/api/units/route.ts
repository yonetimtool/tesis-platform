import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const blok = sp.get("blok");
  if (blok) qs.set("blok", blok);
  const aktif = sp.get("aktif");
  if (aktif === "true" || aktif === "false") qs.set("aktif", aktif);
  return proxyJson(`/units?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units", "POST", body);
}
