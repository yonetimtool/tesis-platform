import { NextRequest, NextResponse } from "next/server";

import { proxyBinary } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DOSYA = /^[A-Za-z0-9._-]+\.(m3u8|ts|mp4)$/;
// Yol adi: `kayit` + 32 hex (kamera) + 16 hex (aralik imzasi). Backend
// ayrica yolun ISTEKTEKI KAMERAYLA esleştigini dogrular (IDOR); burada
// erken kesmek yalnizca gereksiz istegi onler.
const YOL = /^kayit[0-9a-f]{48}$/;

/** (P213 §6) Kayit HLS vekili — canli vekiliyle AYNI kurallar. */
export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string; yol: string; dosya: string[] } },
): Promise<NextResponse> {
  if (!UUID.test(params.id) || !YOL.test(params.yol)) return YOK;
  const dosya = params.dosya.join("/");
  if (params.dosya.length !== 1 || !DOSYA.test(dosya)) return YOK;
  return proxyBinary(`/cameras/${params.id}/kayit/${params.yol}/${dosya}`, "GET");
}
