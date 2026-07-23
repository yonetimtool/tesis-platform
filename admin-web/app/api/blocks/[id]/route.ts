import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/blocks/${params.id}`, "PATCH", body);
}

// Blok silme. ?cascade=true ise blogun daireleri (ve bagli kayitlari) da silinir;
// aksi halde daire varsa backend 409 doner (UI once yazili onay ister). Zarf
// mesaji istemciye aynen iletilir.
export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const cascade = req.nextUrl.searchParams.get("cascade") === "true";
  return proxyJson(`/blocks/${params.id}${cascade ? "?cascade=true" : ""}`, "DELETE");
}
