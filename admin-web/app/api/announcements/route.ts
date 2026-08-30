import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  return proxyJson(`/announcements?${qs.toString()}`, "GET");
}

// (P190 §3) POST GERI GELDI: "olusturma yalniz mobil" kisiti kaldirildi —
// yonetici duyuruyu WEB'DEN de olusturabilir. Backend zaten izinli
// (`_CREATOR = yonetici + admin`, auth.md §4); eski yorumun "admin'e 403"
// iddiasi bayatti. Iki yuzey ayni tabloyu kullanir; mobilde de gorunur.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/announcements", "POST", body);
}
