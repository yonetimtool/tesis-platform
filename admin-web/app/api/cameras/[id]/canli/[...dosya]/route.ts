import { NextRequest, NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// HLS dosyalari disinda hicbir yol vekillenmez (backend de ayni kurali
// uygular; burada erken kesmek gereksiz istegi engeller).
const DOSYA = /^[A-Za-z0-9._-]+\.(m3u8|ts|mp4)$/;

/** (P190 §6) Canli izleme — MediaMTX HLS vekili (playlist + segmentler).
 *  hls.js playlist'i bu BFF adresinden alir; segment adresleri GORELI oldugu
 *  icin onlar da ayni rotaya duser. Kimlik cerezle (BFF), gecit/RTSP adresi
 *  istemciye hic gorunmez. */
export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string; dosya: string[] } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  const dosya = params.dosya.join("/");
  if (params.dosya.length !== 1 || !DOSYA.test(dosya)) return YOK;
  return proxyBinary(`/cameras/${params.id}/canli/${dosya}`, "GET");
}
