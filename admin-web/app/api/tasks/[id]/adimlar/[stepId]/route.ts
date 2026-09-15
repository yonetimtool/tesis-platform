import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P237 §2) Alt adim duzenle / sil. Yetki kurali SUNUCUDA. */
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string; stepId: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tasks/${params.id}/adimlar/${params.stepId}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string; stepId: string } },
): Promise<NextResponse> {
  return proxyJson(`/tasks/${params.id}/adimlar/${params.stepId}`, "DELETE");
}
