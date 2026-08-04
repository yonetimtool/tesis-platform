import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Site kurallari — SALT OKUMA.
 *
 * YAZMA UCU BILEREK ACILMADI: kural yazmak yonetim isidir ve mobilde
 * yapiliyor; buraya bir POST koymak, sakin calisma alaninda yonetim yetkisi
 * varmis izlenimi uretirdi (sunucu zaten reddederdi ama kullanici once
 * dener, sonra 403 gorurdu).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/site-rules?${qs.toString()}`, "GET");
}
