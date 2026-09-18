import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §3) Cihaz komutu — AYRI DOSYA (dinamik eylem vekili YOK).
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/akilli-ev/cihazlar/${params.id}/komut`, "POST", body);
}
