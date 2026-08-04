import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Self-servis iletisim: KENDI telefonu + aranabilir rizasi.
 *
 * Yonetim ucu (`PATCH /users/{id}/contact`) AYRI kalir — bu onun
 * kendi-kaydi karsiligidir. Govde OLDUGU GIBI gecer: alan dogrulamasi
 * SUNUCUDA yapilir ve hata metinleri istegin dilinde doner (tur 14);
 * BFF'te ikinci bir dogrulama iki kuralin ayrismasi demekti.
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/contact", "PATCH", body);
}
