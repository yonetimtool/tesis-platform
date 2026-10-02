import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { setSorgusu } from "@/lib/egitim-bff";


export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P250 §4) `POST /api/egitim-videolari/{adim}/izlendi` — video BITTI. */
export async function POST(
  req: NextRequest,
  { params }: { params: { adim: string } },
): Promise<NextResponse> {
  const adim = encodeURIComponent(params.adim);
  return proxyJson(`/egitim-videolari/${adim}/izlendi${setSorgusu(req)}`, "POST", {});
}
