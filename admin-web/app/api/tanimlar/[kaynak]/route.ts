import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { TANIM_SUZGECLERI, backendYolu } from "@/lib/tanimlar";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * P27 "Tanimlar" katmani icin TEK vekil — dokuz kaynak icin dokuz ayri
 * `route.ts` yerine tek dinamik yol. Guvenlik BEYAZ LISTE ile saglanir
 * (bkz. `@/lib/tanimlar`).
 */
export async function GET(
  req: NextRequest,
  { params }: { params: { kaynak: string } },
): Promise<NextResponse> {
  const yol = backendYolu(params.kaynak);
  if (!yol) return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "100");
  qs.set("offset", sp.get("offset") ?? "0");
  const aktif = sp.get("aktif");
  if (aktif === "true" || aktif === "false") qs.set("aktif", aktif);
  for (const ad of TANIM_SUZGECLERI[params.kaynak] ?? []) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  return proxyJson(`${yol}?${qs.toString()}`, "GET");
}

export async function POST(
  req: NextRequest,
  { params }: { params: { kaynak: string } },
): Promise<NextResponse> {
  const yol = backendYolu(params.kaynak);
  if (!yol) return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  const body = await req.json().catch(() => ({}));
  return proxyJson(yol, "POST", body);
}
