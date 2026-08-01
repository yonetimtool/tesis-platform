import { NextRequest, NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Karar PDF'i — GET, cunku baglanti olarak acilir (yeni sekme). Genel
 *  `[kaynak]` vekili JSON dondurur ve PDF baytlarini bozardi. */
export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  return proxyBinary(`/karar-defteri/${params.id}/pdf`, "GET");
}
