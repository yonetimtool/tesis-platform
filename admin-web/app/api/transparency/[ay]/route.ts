import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Aylık şeffaflık özeti (admin salt-okuma; her ay önizleme). Yayın kontrolü
// panelde YOK — yönetici mobilden yönetir (task: panel read-only).
export async function GET(
  _req: NextRequest,
  { params }: { params: { ay: string } },
): Promise<NextResponse> {
  return proxyJson(`/transparency/${params.ay}`, "GET");
}
