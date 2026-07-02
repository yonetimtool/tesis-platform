import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const kategori = sp.get("kategori");
  if (kategori) qs.set("kategori", kategori);
  const durum = sp.get("durum");
  if (durum) qs.set("durum", durum);
  const aktif = sp.get("aktif");
  if (aktif === "true" || aktif === "false") qs.set("aktif", aktif);
  return proxyJson(`/assets?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/assets", "POST", body);
}
