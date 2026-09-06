import { NextResponse } from "next/server";

import { backendenAl } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Yol IL SLUG'INI DA TASIR: ilce slug'i yalnizca IL ICINDE benzersiz
 * (`UNIQUE (il_id, slug)`) — Turkiye'de birden cok ilde "Merkez" var.
 */
export async function GET(
  istek: Request,
  { params }: { params: { il: string; ilce: string } },
): Promise<NextResponse> {
  const q = new URL(istek.url).searchParams.get("q");
  const ek = q ? `?q=${encodeURIComponent(q)}` : "";
  return backendenAl(
    `/dukkan/lokasyon/il/${encodeURIComponent(params.il)}` +
      `/ilce/${encodeURIComponent(params.ilce)}/mahalle${ek}`,
  );
}
