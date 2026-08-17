import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §2.1/§2.5) Ozet sayfasi duzeni — KULLANICI basina.
 *
 * `localStorage` DEGIL cunku tarayici deposu kullanici basina degil
 * TARAYICI basina calisir: ofisteki bilgisayardan duzenlenen pano,
 * evdeki dizustunde varsayilana donerdi.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/pano-tercihi", "GET");
}

// PUT cunku kayit bir BUTUNDUR — kismi yazma, iki sekme acikken birinin
// otekinin duzenini yarim ezmesine kapi acardi.
export async function PUT(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/pano-tercihi", "PUT", body);
}
