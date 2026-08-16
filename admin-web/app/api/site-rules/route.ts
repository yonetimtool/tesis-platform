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

/**
 * (P162) YAZMA VEKILLERI — WEBDE YONETIM EKRANI ACILDI.
 *
 * Bu dosya P126.3'ten beri SALT OKUMAYDI ve gerekcesi dogruydu: sakin
 * gorunumu (`/kurallar`, `/etkinlikler`) yazma yapmamali. Ama olculdu ki
 * webde YONETIM icin de bir yol yoktu — mobilde tam CRUD varken web
 * yalnizca okuyabiliyordu (bkz. `docs/web-mobil-esitlik.md`).
 *
 * Cozum sakin sayfasina dugme koymak DEGIL (bir kez denendi, `sakin-okuma`
 * kilidi hakli olarak dusurdu); duyurulardaki desenin aynisi: AYRI bir
 * yonetim sayfasi ve onun kullandigi yazma vekilleri.
 *
 * ROL KARARI BURADA VERILMEZ: vekil yalnizca iletir, sunucu `_MANAGER`
 * (admin + yonetici) kapisini uygular. Vekilde suzmek ikinci bir dogruluk
 * kaynagi olurdu.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/site-rules", "POST", body);
}
