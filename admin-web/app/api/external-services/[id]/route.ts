import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P162) Dis hizmet guncelleme/silme vekili — mobilde vardi, webde yoktu.
// Rol karari SUNUCUDA (`_WRITER` = admin + yonetici).
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/external-services/${params.id}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/external-services/${params.id}`, "DELETE");
}
