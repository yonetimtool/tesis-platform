import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

// (P131) Kamera yonetimi — tekil kayit. Yetki sunucuda (admin+yonetici).
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/cameras/${params.id}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/cameras/${params.id}`, "DELETE");
}
