import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Izin onayi — AYRI DOSYA (dinamik eylem vekili YOK).
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/vardiya-izin/${params.id}/onayla`, "POST", {});
}
