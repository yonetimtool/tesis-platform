import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §2) AYRI DOSYA, dinamik `[eylem]` vekili DEGIL: sozlesme kapisi
// dinamik segmenti `/diyafon/{x}/{x}` olarak gorur ve hangi ucun
// cagrildigini OKUNAMAZ kilar (P240 §1'de olculdu).
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/diyafon/${params.id}/saglik`, "POST", body);
}
