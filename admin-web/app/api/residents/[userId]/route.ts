import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: NextRequest,
  { params }: { params: { userId: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/residents/${params.userId}`, "PATCH", body);
}

/** Sakini SIL / ANONIMLESTIR (P189 akilli silme).
 *
 * Yanit `{"deleted": bool}` — `false` "basarisiz" DEMEK DEGIL:
 * gecmisi olan sakin silinmez, ANONIMLESTIRILIR ve satir kalir. Arayuz
 * ikisini ayri anlatmali, yoksa yonetici islemin yarim kaldigini
 * sanirdi. */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: { userId: string } },
): Promise<NextResponse> {
  return proxyJson(`/residents/${params.userId}`, "DELETE");
}
