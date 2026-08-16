import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P163 §1) DINAMIK SEGMENT ARTIK KIMLIK DOGRULAR.
 *
 * OLCULEN KUSUR: bu dosya `/api/units/<herhangi-bir-sey>` icin
 * esliyordu. `bulk` ve `kat-sil` gibi YAPISAL yollar buraya dusuyor,
 * metot tanimli olmadigi icin 405 aliyordu; `toplu` ve `siralama` ise
 * `PATCH` tanimli oldugu icin KAZAYLA calisiyordu (`/units/${id}`
 * tesadufen dogru URL'yi kuruyordu).
 *
 * Artik kimlik UUID degilse 404 doner. Boylece yanlis eslesme SESSIZ
 * kalmaz: yeni bir yapisal yol eklenip vekili unutulursa "bulunamadi"
 * denir, "yontem yok" degil — ve gercek sebep aranacak yer bellidir.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  return proxyJson(`/units/${params.id}`, "GET");
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/units/${params.id}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  return proxyJson(`/units/${params.id}`, "DELETE");
}
