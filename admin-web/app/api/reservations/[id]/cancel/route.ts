import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Kendi rezervasyonunu iptal et (sunucu sahiplik dogrular). */
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/reservations/${params.id}/cancel`, "POST");
}
