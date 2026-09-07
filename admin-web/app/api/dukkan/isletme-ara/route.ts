import { NextResponse } from "next/server";

import { vekilGet } from "@/lib/dukkan-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (DUKKAN F6) BFF vekili — "Yerel İşletmeler" sayfası için. */
export async function GET(istek: Request): Promise<NextResponse> {
  return vekilGet(istek, "/dukkan/isletme-ara");
}
