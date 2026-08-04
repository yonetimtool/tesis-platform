import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Sakinin KENDI aidat durumu.
 *
 * Paneldeki `/api/dues` YONETIM ucudur (tahakkuk olusturur, tum daireleri
 * listeler). Bu onun kendi-kaydi karsiligidir: sunucu `GET /me/dues` ile
 * YALNIZ kullanicinin bagli oldugu daireleri doner. Ayni ucu rol suzgeciyle
 * paylasmak, bir gun suzgec unutuldugunda tum sitenin borcunu sakine
 * gostermek olurdu.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/dues", "GET");
}
