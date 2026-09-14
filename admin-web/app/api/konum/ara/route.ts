import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P233 §1) Konum arama vekili.
 *
 * SORGU DIZESI ILETILIR (P226 dersi): `q` dusurulurse uc 422 doner ve
 * arayuz "konum bulunamadi" gibi YANLIS bir sey gosterir.
 *
 * YETKI SUNUCUDA: `/konum/ara` admin + yonetici ile korunuyor; BFF
 * kuralı TEKRARLAMAZ.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/konum/ara${req.nextUrl.search}`, "GET");
}
