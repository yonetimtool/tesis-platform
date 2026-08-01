import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { okumaYolu, yazmaYolu } from "@/lib/panel-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });

/** Kimlik UUID OLMALI: yol parcasini dogrulamadan gecirmek, `..` ya da
 *  `x/../users` gibi bir parcanin backend yoluna sizmasi demekti. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function hedef(kaynak: string, id: string, ek?: string): string | null {
  if (!UUID.test(id)) return null;
  const kok = yazmaYolu(kaynak) ?? okumaYolu(kaynak);
  if (!kok) return null;
  return ek ? `${kok}/${id}/${ek}` : `${kok}/${id}`;
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { kaynak: string; id: string } },
): Promise<NextResponse> {
  const yol = hedef(params.kaynak, params.id);
  if (!yol) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(yol, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { kaynak: string; id: string } },
): Promise<NextResponse> {
  const yol = hedef(params.kaynak, params.id);
  if (!yol) return YOK;
  return proxyJson(yol, "DELETE");
}
