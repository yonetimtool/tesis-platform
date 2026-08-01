import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { SUZGECLER, okumaYolu, yazmaYolu } from "@/lib/panel-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });

export async function GET(
  req: NextRequest,
  { params }: { params: { kaynak: string } },
): Promise<NextResponse> {
  const yol = okumaYolu(params.kaynak);
  if (!yol) return YOK;
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  // Sayfalama HER KAYNAKTA ayni: panel tarafinda tek desen.
  if (sp.get("limit")) qs.set("limit", sp.get("limit") as string);
  if (sp.get("offset")) qs.set("offset", sp.get("offset") as string);
  for (const ad of SUZGECLER[params.kaynak] ?? []) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  const sorgu = qs.toString();
  return proxyJson(sorgu ? `${yol}?${sorgu}` : yol, "GET");
}

export async function POST(
  req: NextRequest,
  { params }: { params: { kaynak: string } },
): Promise<NextResponse> {
  const yol = yazmaYolu(params.kaynak);
  if (!yol) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(yol, "POST", body);
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { kaynak: string } },
): Promise<NextResponse> {
  // PATCH hedefi kaynak KOKUDUR (orn. `/portal`); alt kaynak guncellemeleri
  // `[kaynak]/[id]` yolundan gecer.
  const yol = yazmaYolu(params.kaynak) ?? okumaYolu(params.kaynak);
  if (!yol) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(yol, "PATCH", body);
}
