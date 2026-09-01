import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P193 §7) `POST /api/users/odeme-kodlari` — sakinlerin havale kodlari.
 *
 * AYRI DOSYA SART: `app/api/users/[id]/route.ts` bu yolu `id`
 * ("odeme-kodlari") sanardi ve backend'e `/users/odeme-kodlari` yerine
 * bir UUID beklenen yola giderdi. Next'te DURAGAN segment dinamik
 * segmenti yener; dosyanin varligi bu yuzden bir karardir, kopya degil.
 *
 * NEDEN POST: uc YAZAR — eksik kodlari uretir (kodlar tembel uretiliyor
 * ve cogu sakinin kodu hic yok). Salt okuyan bir cagri bos liste
 * dondururdu.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/users/odeme-kodlari", "POST", body);
}
