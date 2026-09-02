import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §5) Aylik personel gideri ozeti.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("yil", sp.get("yil") ?? "");
  qs.set("ay", sp.get("ay") ?? "");
  return proxyJson(`/mesai/ozet?${qs.toString()}`, "GET");
}
