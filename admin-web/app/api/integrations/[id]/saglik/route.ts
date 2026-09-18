import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §4) BAGLANTI KONTROLU — entegrasyonu TETIKLEMEZ.
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/integrations/${params.id}/saglik`, "POST", {});
}
