import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P163 §1) TOPLU DAIRE OLUSTURMA VEKILI — 405'IN KOK NEDENI BUYDU.
 *
 * =========================================================================
 * NE OLUYORDU
 * =========================================================================
 * Panel `POST /api/units/bulk` cagiriyordu. Bu yolun VEKILI YOKTU; Next
 * istegi `app/api/units/[id]/route.ts`ye (id = "bulk") esliyordu ve o
 * dosyada `POST` TANIMLI DEGILDI. Next, eslesen dosyada metot yoksa
 * **405 Method Not Allowed** doner — istek hicbir govdeye ulasmaz.
 *
 * Sunucu log'unda traceback OLMAMASININ sebebi tam olarak bu: istek
 * backend'e HIC GITMEDI, yonlendirme katmaninda oldu.
 *
 * Uc ve sozlesme dogruydu: `contracts/openapi.yaml` -> `/units/bulk: post`,
 * `backend/app/routers/units.py` -> `@router.post("/bulk")`. Eksik olan
 * TEK halka BFF'ti.
 *
 * =========================================================================
 * NEDEN ACIK ROTA, NEDEN `[id]`YE POST EKLEMEK DEGIL
 * =========================================================================
 * `[id]`ye `POST` eklemek 405'i susturur ama YANLIS BIR KAPI acardi:
 * `/api/units/<herhangi-bir-sey>` POST kabul eder hale gelirdi. Yapisal
 * uclar SABIT ve SAYILIDIR; her birinin kendi vekili olmali. Next'te
 * duz segment dinamik segmenti YENER, yani bu dosya `[id]`den once
 * eslesir.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/units/bulk", "POST", body);
}
