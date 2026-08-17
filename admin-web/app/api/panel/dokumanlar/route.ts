import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §6.3) DOKUMAN LISTESI + KAYIT.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA — `[kaynak]` vekili YETMEZ
 * =========================================================================
 * `dokumanlar` beyaz listede zaten vardi ve `[kaynak]` vekili isini
 * goruyordu. Ama `/dokumanlar/{id}/indir` ucu UCUNCU bir segment tasiyor
 * ve onun icin `app/api/panel/dokumanlar/[id]/indir/route.ts` acildi.
 *
 * Next'te DUZ SEGMENT dinamigi YENER: o dizin var oldugu andan itibaren
 * `/api/panel/dokumanlar` artik `[kaynak]`a DUSMEZ — ve dosya olmasaydi
 * liste sessizce 404 verirdi. Bu tam olarak P163'un olctugu 405/404
 * sinifi.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  if (sp.get("limit")) qs.set("limit", sp.get("limit") as string);
  if (sp.get("offset")) qs.set("offset", sp.get("offset") as string);
  const sorgu = qs.toString();
  return proxyJson(sorgu ? `/dokumanlar?${sorgu}` : "/dokumanlar", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/dokumanlar", "POST", body);
}
