import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

/**
 * (P173) ICE AKTARIMI GERI AL — EKSIK ROTA.
 *
 * =========================================================================
 * NASIL BULUNDU
 * =========================================================================
 * Bu turda eklenen `tests/uc-sozlesme-kapisi.test.ts` buldu — aranarak
 * degil, TARANARAK. Arayuz `POST /api/panel/ice-aktarim/{id}/geri-al`
 * cagiriyordu; genel vekil `[kaynak]/[id]` YALNIZ IKI segment eslestirir,
 * ucuncu segment (`geri-al`) icin hicbir rota yoktu ve istek 404
 * aliyordu. Uc backend'de ve sozlesmede VARDI.
 *
 * Yani "Geri al" dugmesi ekranda duruyor, basiliyor ve hicbir sey
 * olmuyordu — `mesaj-ayarlari` ile AYNI sinif, ucuncu ornek.
 *
 * =========================================================================
 * NEDEN KENDI ROTASI
 * =========================================================================
 * Genel vekile ucuncu bir segment eklemek, her kaynagin her kimligine
 * KEYFI bir alt-eylem gonderilebilen bir kapi acardi ve beyaz listenin
 * anlami zayiflardi. Alt-eylemler acikca yazilir.
 */
export async function POST(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/ice-aktarim/${id}/geri-al`, "POST");
}
