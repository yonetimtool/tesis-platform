import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Pazarlama izinleri — UC BAGIMSIZ KANAL (e-posta / SMS / arama).
 *
 * Tek bir "pazarlama" bayragi, kisiyi istemedigi kanaldan mesaj almak ile
 * hic almamak arasinda secmeye zorlardi (sunucu semasinin gerekcesi).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/pazarlama-tercihleri", "GET");
}

export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/pazarlama-tercihleri", "PATCH", body);
}
