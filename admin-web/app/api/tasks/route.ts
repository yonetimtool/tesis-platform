import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  // (P160) `tip` GECISI KALDIRILDI: `GET /tasks` boyle bir parametre
  // ALMIYOR (FastAPI bilinmeyeni yok sayar), yani bu satir istegi
  // buyutup hicbir sey yapmiyordu. Gorev tipi 087f33f'te dinamik
  // `kategori_id`ye cevrilmisti; o parametre asagida zaten geciyor.
  const aktif = sp.get("aktif");
  if (aktif === "true" || aktif === "false") qs.set("aktif", aktif);
  const atanan = sp.get("atanan_user_id");
  if (atanan) qs.set("atanan_user_id", atanan);
  return proxyJson(`/tasks?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/tasks", "POST", body);
}
