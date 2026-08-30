import { NextRequest, NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** (P190 §6) RTSP kameradan tek kare (JPEG) — sunucu ceker, kimlik bilgisi
 *  istemciye gitmez. Izgara karosu periyodik olarak bunu tazeler. */
export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  return proxyBinary(`/cameras/${params.id}/kare`, "GET");
}
