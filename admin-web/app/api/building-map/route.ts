import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// GET /unit-complaints/building-map — cizilebilir bina semasi (blok->kat->daire
// + renk) + unplaced. Tum roller okur (tenant-ici anonim harita).
export async function GET(): Promise<NextResponse> {
  return proxyJson("/unit-complaints/building-map", "GET");
}
