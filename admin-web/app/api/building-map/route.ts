import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (E2E 2026-09) TESIS-17: tur secicisi — sorgu BEYAZ LISTEYLE tasinir
// (keyfi parametre backend'e gecmez).
const KATEGORILER = new Set([
  "gurultu",
  "kapi_onu_ayakkabi",
  "zarar_verme",
  "goruntu_kirliligi",
  "diger",
]);

// GET /unit-complaints/building-map — cizilebilir bina semasi (blok->kat->daire
// + renk) + unplaced. Tum roller okur (tenant-ici anonim harita).
export async function GET(req: NextRequest): Promise<NextResponse> {
  const kategori = req.nextUrl.searchParams.get("kategori");
  const qs =
    kategori && KATEGORILER.has(kategori)
      ? `?kategori=${encodeURIComponent(kategori)}`
      : "";
  return proxyJson(`/unit-complaints/building-map${qs}`, "GET");
}
