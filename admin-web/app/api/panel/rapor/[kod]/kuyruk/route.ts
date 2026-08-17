import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Rapor KODU: katalogdan gelir, ama yol parcasina girdigi icin yine de
 *  bicimi dogrulanir — serbest metin gecirmek `../` sinifini acardi. */
const KOD = /^[a-z0-9_]{2,40}$/;

/** Kuyruk YALNIZ dosya uretir. `tablo` BILEREK YOK: tablo ciktisi ekranda
 *  gosterilir ve zaten hizlidir; kuyruga almak kullaniciyi gormek istedigi
 *  seyi beklemeye zorlamak olurdu. */
const BICIMLER = ["excel", "pdf"];

export async function POST(
  req: NextRequest,
  { params }: { params: { kod: string } },
): Promise<NextResponse> {
  if (!KOD.test(params.kod)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const bicim = req.nextUrl.searchParams.get("bicim") ?? "";
  if (!BICIMLER.includes(bicim)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/raporlar/${params.kod}/kuyruk?bicim=${bicim}`, "POST", body);
}
