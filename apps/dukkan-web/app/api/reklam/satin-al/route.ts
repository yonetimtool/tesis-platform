import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili. Tarayici backend'e DOGRUDAN gitmez (lib/backend.ts).
 *
 * KART BILGISI BU VEKILDEN GECMEZ: govde yalniz paket, bolge ve fatura
 * alanlarini tasir. Kart, saglayicinin kendi sayfasinda giriliyor. */
export async function POST(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/reklam/satin-al");
}
