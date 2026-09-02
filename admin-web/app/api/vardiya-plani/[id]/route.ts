import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P203 §4.3) Atamayi kaldir.
 *
 * `not_metni` SORGUDA tasinir: DELETE govdesi bazi vekillerde ve
 * `fetch` uygulamalarinda SESSIZCE dusuyor — sebep alani da boyle
 * kaybolurdu ve denetim kaydi "neden" sorusunu yanitlayamazdi.
 */
export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const not = req.nextUrl.searchParams.get("not_metni");
  const qs = not ? `?not_metni=${encodeURIComponent(not)}` : "";
  return proxyJson(`/vardiya-plani/${params.id}${qs}`, "DELETE");
}

/**
 * (P205 §2.3) Blogun saatini/gununu degistir.
 *
 * PATCH BURADA EXPORT EDILMEK ZORUNDA: backend ucu olsa bile
 * `route.ts` metodu disa vermezse istek 405 alir — tekrar eden bir
 * sinif (P173/P189/P205).
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/vardiya-plani/${params.id}`, "PATCH", body);
}
