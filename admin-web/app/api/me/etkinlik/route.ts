import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) Kendi hesap etkinligim — son N denetim satiri.
 *
 * `/api/audit` DEGIL: o tesisin TAMAMINI gosterir ve admin/denetci
 * yetkisi ister. Burasi her role acik ve yalniz kisinin kendi satirlarini
 * doner; suzgec SUNUCUDAKI sorgunun icindedir.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const limit = req.nextUrl.searchParams.get("limit");
  const q = limit ? `?limit=${encodeURIComponent(limit)}` : "";
  return proxyJson(`/me/etkinlik${q}`, "GET");
}
