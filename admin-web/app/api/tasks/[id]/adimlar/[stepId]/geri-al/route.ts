import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P237 §2) Alt adim tamamlamasini geri al — YALNIZ YONETIM (sunucuda). */
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string; stepId: string } },
): Promise<NextResponse> {
  return proxyJson(
    `/tasks/${params.id}/adimlar/${params.stepId}/geri-al`,
    "POST",
    {},
  );
}
