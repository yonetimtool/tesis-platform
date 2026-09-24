import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (E2E 2026-09 / GUVENLIK-14) Daire ARAMA — numara VEYA SAKIN ADIYLA
 * (`GET /units/ara`, P203 §3). Mobil ziyaretci formu bu ucu kullaniyordu;
 * web formu daireyi serbest metinle aliyordu ve hedef sakin secicisi
 * YOKTU (`target_resident_user_id` zorunlu -> her kayit 422).
 *
 * Sorgu BEYAZ LISTEYLE tasinir (`q`, `limit`) — vekil suzgeci dusurmesin
 * (P173/P189/P213/P245 sinifi) ama baska parametre de sizmasin.
 * `ara` STATIK segment: `[id]` dinamik rotasindan once eslesir.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({ q: sp.get("q") ?? "" });
  const limit = sp.get("limit");
  if (limit) qs.set("limit", limit);
  return proxyJson(`/units/ara?${qs.toString()}`, "GET");
}
