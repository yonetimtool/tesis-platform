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
  return proxyJson(`/notifications?${qs.toString()}`, "GET");
}
