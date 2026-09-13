import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.6) Gorev tamamlama.
 *
 * `Idempotency-Key` ILETILIR: sunucu onu ZORUNLU tutuyor (400
 * `idempotency_key_zorunlu`). Cift tiklama ya da ag tekrari, ayni gorevi
 * iki kez tamamlanmis gostermemeli.
 */
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  const key = req.headers.get("Idempotency-Key");
  return proxyJson(
    `/tasks/${params.id}/completions`,
    "POST",
    body,
    key ? { "Idempotency-Key": key } : undefined,
  );
}

/**
 * (P229 §3) TAMAMLAMA GECMISI — GET.
 *
 * =========================================================================
 * OLCULEN KUSUR: BU METOT HIC EXPORT EDILMEMISTI
 * =========================================================================
 * `app/(protected)/tasks/page.tsx` detay panelinde
 * `/api/tasks/{id}/completions?limit=50&offset=0` okuyor ve tabloyu
 * ciziyordu. Arka uc ucu VARDI, sayfa kodu VARDI — arada BFF rotasi
 * yalnizca POST export ediyordu, yani istek 405 aliyordu ve tablo HIC
 * DOLMUYORDU.
 *
 * P189 ve P226'da olculen sinifin AYNISI: "iki uc ayri ayri dogru, ORTA
 * HALKA olculmemis". Sorgu dizesi de iletilmeli (P226): `limit`/`offset`
 * dusurulurse sayfalama sessizce ilk sayfaya cakilir.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const qs = req.nextUrl.search;
  return proxyJson(`/tasks/${params.id}/completions${qs}`, "GET");
}
