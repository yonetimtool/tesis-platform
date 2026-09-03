import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P207 §1) Kalibi sil — ondan olusmus PLANLAR KALIR.
export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/vardiya-plani/kaliplar/${params.id}`, "DELETE");
}
