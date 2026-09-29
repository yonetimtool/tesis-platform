import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P249 §1b) DAIRE BAZINDA DURUM — kim guvende, kim yardim istiyor, kim
// yanit vermedi. Yetki sunucuda (yalniz yonetim/guvenlik).
export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/panik/${params.id}/durum`, "GET");
}
