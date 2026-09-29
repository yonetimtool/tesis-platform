import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P249 §2) Tatbikat eylemi (iptal) — AYRI DOSYA: dinamik `[eylem]` vekili
// hangi ucun cagrildigini sozlesme kapisina okunamaz kilardi (P240 notu).
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/tatbikat/${params.id}/iptal`, "POST", {});
}
