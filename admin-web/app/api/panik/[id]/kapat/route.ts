import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §1) Alarm eylemi — AYRI DOSYA, dinamik `[eylem]` vekili DEGIL.
//
// Serbest bir vekil (`/panik/{id}/<ne-yazarsan>`) iki seyi birden
// bozuyordu: (a) yarin eklenen bir uc, panel tarafinda hic dusunulmeden
// acilmis olurdu; (b) sozlesme kapisi (`uc-sozlesme-kapisi`) yolu
// `/panik/{x}/{x}` olarak gorup "sozlesmede yok" diyordu — yani kilit
// HAKLIYDI: dinamik segment, hangi ucun cagrildigini OKUNAMAZ kiliyor.
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/panik/${params.id}/kapat`, "POST", body);
}
