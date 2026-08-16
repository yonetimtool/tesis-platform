import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P162) Guncelleme/silme vekili — yonetim sayfasi icin. Rol karari
// SUNUCUDA (`_MANAGER`); burada yalnizca iletim var.
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/events/${params.id}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/events/${params.id}`, "DELETE");
}
