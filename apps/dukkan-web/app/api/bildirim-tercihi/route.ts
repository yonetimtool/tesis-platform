import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * BFF vekili — Dukkan bildirim tercihi.
 *
 * IKI METOT DA EXPORT EDILIYOR. Yalniz GET yazilsaydi PATCH cagrisi 405
 * donerdi ve backend ucu CALISIYOR oldugu icin backend testleri bunu
 * GORMEZDI (P173/P189'da iki kez yasandi; `uc-sozlesme-kapisi.test.ts`
 * bu sinifi olcuyor).
 */
export async function GET(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/bildirim-tercihi");
}

export async function PATCH(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/bildirim-tercihi");
}
