import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P232 §A) VARDIYA SABLONUNUN VARSAYILAN KADROSU.
 *
 * =========================================================================
 * OLCULEN KUSUR: BU ROTA HIC YOKTU
 * =========================================================================
 * Arka ucta `PUT /shifts/{id}/assignments` VARDI ve MOBIL onu
 * kullaniyordu (`shifts_api.dart` → `updateAssignments`). Web'de ise
 * karsiligi YOKTU: `/shifts` sayfasi sablonu tanimliyor ama kimseyi
 * atayamiyordu.
 *
 * Sonucu gorunurdu ve sasirticiydi: `/vardiya-plani`daki "Haftayi
 * doldur" dugmesi kadroyu okuyup haftayi dolduruyor — ama kadro yalniz
 * telefondan girilebildigi icin web kullanicisinda HICBIR SEY
 * yapmiyordu. Sayfanin "bos" gorunmesinin sebebi de buydu: sablon
 * tanimlamanin bir karsiligi yoktu.
 *
 * P226/P229 dersinin aynisi: iki uc ayri ayri dogru, ORTA HALKA eksik.
 *
 * YETKI SUNUCUDA: arka uc `_YAZAR` ile korur (P35 `guvenlik_modu`
 * sahipligi dahil). BFF yalnizca yolu acar.
 */
export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const govde = await req.json().catch(() => ({}));
  return proxyJson(`/shifts/${params.id}/assignments`, "PUT", govde);
}
