import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P154 / Asama 4) Callback'in biraktigi tek kullanimlik sonucu isler.
 *
 * IKI SONUC, IKI DAVRANIS:
 *   * `giris`           -> jetonlar CEREZE yazilir, govdeye KOYULMAZ,
 *   * `baglama_gerekli` -> govde aynen gecer (tesis kodu + telefon adimi).
 *
 * Jetonlari govdede dondurmek, panelde jetonun JS'e hic gorunmemesi
 * kuralini yalniz bu ekran icin delerdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/oauth/sonuc",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    durum?: string;
    jetonlar?: { access_token?: string; refresh_token?: string };
  };
  if (govde.durum !== "giris") return NextResponse.json(govde);
  const j = govde.jetonlar;
  if (!j?.access_token || !j.refresh_token) {
    return NextResponse.json(govde, { status: 502 });
  }
  return oturumAc(req, j.access_token, j.refresh_token);
}
