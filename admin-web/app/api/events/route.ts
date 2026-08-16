import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Etkinlikler — SALT OKUMA (yazma yonetim isidir, bkz. site-rules). */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  return proxyJson(`/events?${qs.toString()}`, "GET");
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
  return proxyJson("/events", "POST", body);
}
