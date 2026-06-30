import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const unitId = sp.get("unit_id");
  if (unitId) qs.set("unit_id", unitId);
  const donem = sp.get("donem");
  if (donem) qs.set("donem", donem);
  return proxyJson(`/dues/assessments?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/dues/assessments", "POST", body);
}
