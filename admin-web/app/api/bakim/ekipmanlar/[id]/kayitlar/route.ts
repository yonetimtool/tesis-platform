import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §1) Bakim yapildi — kayit + tarih ilerlemesi + gider.
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/bakim/ekipmanlar/${params.id}/kayitlar`, "POST", body);
}
