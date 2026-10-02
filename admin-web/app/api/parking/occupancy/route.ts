import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P251 §8) Otopark dolulugu — "Otopark ve arac gecisleri" TEK modul.
 * Mobil "Otopark" ekraninin okudugu ucun aynisi; doluluk acik gecis
 * kayitlarindan sayilir (plaka/daire icermez).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/parking/occupancy", "GET");
}
