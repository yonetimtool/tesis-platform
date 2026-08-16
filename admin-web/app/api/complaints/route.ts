import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const durum = sp.get("durum");
  if (durum) qs.set("durum", durum);
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
