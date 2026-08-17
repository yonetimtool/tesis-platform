import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f-]{36}$/i;

/** (P167 ek) Dokumani sakine AC / KAPAT. */
export async function PATCH(
  req: Request,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/dokumanlar/${params.id}`, "PATCH", body);
}

/** (P167 §6.3) Dokuman SILME. `[kaynak]/[id]` vekilinden devralindi —
 *  gerekce kardes `route.ts` dosyasinda: duz segment dinamigi yener. */
export async function DELETE(
  _req: Request,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  return proxyJson(`/dokumanlar/${params.id}`, "DELETE");
}
