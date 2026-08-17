import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) "Guvenilen cihazlar" — kullanicinin KENDI cihazlari.
 *
 * `/api/panel/devices` DEGIL: o uc tenant'in TUM cihazlarini doner ve
 * yalniz admin'e aciktir. Burasi her role acik, kisinin yalniz kendi
 * satirlarini goren AYRI bir uc (sunucu tarafi gerekcesi `me.py`de).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/cihazlar", "GET");
}
