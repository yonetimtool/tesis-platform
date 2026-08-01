import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** (P37) Manuel anonsu "yapildi" isaretle. Genel `[kaynak]/[id]` vekili
 *  PATCH/DELETE tasir; bu uc POST ve ALT YOL (`/yapildi`) istedigi icin
 *  ayri — vekile serbest bir alt-yol parametresi eklemek, beyaz listenin
 *  anlamini bosaltirdi. */
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  return proxyJson(`/unit-uyarilari/${params.id}/yapildi`, "POST", {});
}
