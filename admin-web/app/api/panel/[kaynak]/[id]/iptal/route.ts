import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { okumaYolu, yazmaYolu } from "@/lib/panel-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// (P189) BFF EKSIK ROTA (P173 sinifi): finans hareket sayfasi
// POST /api/panel/{kaynak}/{id}/iptal (hareket iptali) cagiriyordu ama uc-eylem
// (`[kaynak]/[id]/iptal`) rotasi hic yoktu -> 405. `[kaynak]/[id]` vekili
// yalniz 2 segmenti (PATCH/DELETE) karsiliyor; eylem segmenti buraya dusuyor.
// Kaynak whitelist'ten (yazmaYolu) cozulur; "iptal" eylemi yol'da SABITTIR
// (kullanicidan gelmez) — arbitrer eylem vekillenemez. Backend: POST
// /finans/hareketler/{id}/iptal.
export async function POST(
  req: NextRequest,
  { params }: { params: { kaynak: string; id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  const kok = yazmaYolu(params.kaynak) ?? okumaYolu(params.kaynak);
  if (!kok) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`${kok}/${params.id}/iptal`, "POST", body);
}
