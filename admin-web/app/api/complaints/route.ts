import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  // (E2E 2026-09) BEYAZ LISTE `oncelik` ve `unit_id` ile GENISLEDI.
  // Olculen: ozet sayfasi `durum=acik&oncelik=yuksek` soruyordu, vekil
  // `oncelik`i DUSURUYOR ve tum acik talepleri sayiyordu — kart "8 yüksek
  // öncelikli" diyordu, gercekte 0. Uc (`complaints.py list_complaints`)
  // ikisini de destekliyor. (P245 §7 visitors suzgeci ile ayni sinif.)
  for (const ad of ["durum", "oncelik", "unit_id"] as const) {
    const deger = sp.get(ad);
    if (deger) qs.set(ad, deger);
  }
  return proxyJson(`/complaints?${qs.toString()}`, "GET");
}

/**
 * (P163 §1) TALEP ACMA VEKILI — UCUNCU 405.
 *
 * `units/bulk` icin yazilan tarama (`tests/bff-yol-eslesmesi.test.ts`)
 * bunu da buldu ve HENUZ KIMSE BILDIRMEMISTI: `/taleplerim` ekranindaki
 * "Talep ac" dugmesi `POST /api/complaints` cagiriyor, bu dosyada YALNIZ
 * `GET` tanimliydi ve Next 405 donuyordu. Yani sakin webden talep
 * ACAMIYORDU.
 *
 * Uc (`complaints.py: @router.post("")`) ve sozlesme
 * (`openapi.yaml: /complaints: post`) dogruydu; eksik olan yine BFF'ti.
 *
 * ROL KARARI SUNUCUDA: vekil yalnizca iletir.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/complaints", "POST", body);
}
