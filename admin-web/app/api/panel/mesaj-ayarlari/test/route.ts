import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P173) TEST GONDERIMI — KENDI ROTASI.
 *
 * =========================================================================
 * NEDEN `[kaynak]/[id]` DEGIL
 * =========================================================================
 * Istemci `/api/panel/mesaj-ayarlari/test` cagiriyor. Genel vekilde bu,
 * `[kaynak]=mesaj-ayarlari` + `[id]=test` olarak cozulurdu — ama "test"
 * bir KIMLIK DEGIL, bir EYLEM. Ustelik o dosyada `POST` isleyicisi yok:
 * istek 405 ile reddediliyor ve uc govdesine HIC ulasmiyordu.
 *
 * `[kaynak]/[id]`ye POST eklemek daha kotu olurdu: her kaynagin her
 * kimligine POST atilabilen genel bir kapi acardi ve beyaz listenin
 * anlami zayiflardi.
 *
 * Next STATIK segmenti dinamikten ONCE cozer, yani bu dosya
 * `[kaynak]/[id]`nin onune gecer — ek bir yapilandirma gerekmiyor.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/mesaj-ayarlari/test", "POST", body);
}
