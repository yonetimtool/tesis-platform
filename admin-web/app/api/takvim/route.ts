import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 Asama 2) TAKVIM — alti kaynagin birlesik okumasi.
 *
 * Istemci alti listeyi ayri ayri cekseydi, kullanici her ay okunu
 * tikladiginda ALTI gidis-donus olurdu ve ucu gelip ucu gelmediginde
 * takvim yarim cizilirdi. Birlestirme SUNUCUDA.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const s = req.nextUrl.searchParams;
  const q = new URLSearchParams();
  for (const ad of ["baslangic", "bitis"]) {
    const v = s.get(ad);
    if (v) q.set(ad, v);
  }
  return proxyJson(`/takvim?${q.toString()}`, "GET");
}
