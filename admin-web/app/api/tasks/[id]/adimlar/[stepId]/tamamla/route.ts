import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P237 §2) Alt adimi tamamla — fotograf + not. */
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string; stepId: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(
    `/tasks/${params.id}/adimlar/${params.stepId}/tamamla`,
    "POST",
    body,
  );
}
