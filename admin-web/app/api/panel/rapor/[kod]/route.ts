import { NextRequest, NextResponse } from "next/server";

import { proxyBinary, proxyJson } from "@/lib/backend";
import { RAPOR_BICIMLERI } from "@/lib/panel-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Rapor KODU: katalogdan gelir, ama yol parcasina girdigi icin yine de
 *  bicimi dogrulanir — serbest metin gecirmek `../` sinifini acardi. */
const KOD = /^[a-z0-9_]{2,40}$/;

export async function POST(
  req: NextRequest,
  { params }: { params: { kod: string } },
): Promise<NextResponse> {
  if (!KOD.test(params.kod)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const bicim = req.nextUrl.searchParams.get("bicim") ?? "tablo";
  if (!RAPOR_BICIMLERI.includes(bicim)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const body = await req.json().catch(() => ({}));
  const yol = `/raporlar/${params.kod}?bicim=${bicim}`;
  // TABLO JSON, digerleri IKILI: tek bir vekil kullanmak, XLSX baytlarini
  // JSON diye ayristirip bozmak olurdu.
  return bicim === "tablo"
    ? proxyJson(yol, "POST", body)
    : proxyBinary(yol, "POST", body);
}
