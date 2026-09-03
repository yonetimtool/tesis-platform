import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P207 §1) Toplu islemi geri al — 30 gunluk yanlis plan tek istekle.
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/vardiya-plani/parti/${params.id}/geri-al`, "POST", {});
}
