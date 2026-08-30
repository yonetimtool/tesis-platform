import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191 §4) Ekstre iceri aktarma.
 *
 * Govde ALANLARI SECILEREK gecirilir (arka uc `extra="forbid"`): dosyayi
 * PANEL ayristirir ve buradan yalnizca yapilandirilmis satirlar gecer.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const g = (await req.json().catch(() => ({}))) as {
    kaynak?: string;
    satirlar?: unknown[];
    mt940?: string;
  };
  const govde: Record<string, unknown> = { kaynak: g.kaynak ?? "ekstre" };
  if (g.mt940) govde.mt940 = g.mt940;
  else govde.satirlar = g.satirlar ?? [];
  return proxyJson("/banka/ice-aktar", "POST", govde);
}
