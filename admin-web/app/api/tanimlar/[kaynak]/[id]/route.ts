import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { backendYolu } from "@/lib/tanimlar";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Tekil kayit — kaynak adi yine BEYAZ LISTEDEN cozulur (bkz. ust yol). */
export async function PATCH(
  req: NextRequest,
  { params }: { params: { kaynak: string; id: string } },
): Promise<NextResponse> {
  const yol = backendYolu(params.kaynak);
  if (!yol) return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  const body = await req.json().catch(() => ({}));
  return proxyJson(`${yol}/${encodeURIComponent(params.id)}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { kaynak: string; id: string } },
): Promise<NextResponse> {
  const yol = backendYolu(params.kaynak);
  if (!yol) return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  return proxyJson(`${yol}/${encodeURIComponent(params.id)}`, "DELETE");
}
