import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P221) Genel ozellik bayraklari — BFF vekili.
 *
 * Uc backend'de KIMLIKSIZ; vekil yine de gerekli cunku tarayici
 * backend'e DOGRUDAN gitmiyor (CORS + tek konak kurali). Vekil
 * olmasaydi istek Next'in 404'une duser ve bayrak SESSIZCE eksik
 * gelirdi — istemci kapali varsayar, yani "yakinda" ekrani hic
 * acilmazdi. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/ozellikler", "GET");
}
