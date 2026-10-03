import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P253 §D) Daireye gelen sikayetlerin ORUNTUSU — sayi + farkli kaynak +
// tek kaynak uyarisi. Kimlik ve kaynak etiketi YOK.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const qs = new URLSearchParams();
  const unit = req.nextUrl.searchParams.get("unit_id");
  if (unit) qs.set("unit_id", unit);
  return proxyJson(`/unit-complaints/kaynak-ozeti?${qs.toString()}`, "GET");
}
