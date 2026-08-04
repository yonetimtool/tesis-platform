import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.5) Kameralar — SALT OKUMA.
 *
 * YONETIM (ekle/duzenle/sil) BU DILIMDE ACILMADI: kamera kaydinin
 * desteklenen-kaynak kurali (HLS/MP4 evet, web sayfasi hayir) mobilde
 * `CameraDraft` icinde yasiyor (P121). Ayni kurali TS'e ikinci kez yazmak,
 * iki kopyanin zamanla ayrismasi demekti — ve ayrisirsa biri "kaydettim
 * ama acilmiyor" uretir. Yonetim mobilde kalir; web izler.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/cameras?${qs.toString()}`, "GET");
}
