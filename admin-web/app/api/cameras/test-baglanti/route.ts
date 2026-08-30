import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191 §3) Kamera baglanti testi — kaydetmeden dene.
 *
 * Govde ALANLARI SECILEREK gecirilir: istemcinin gonderdigi her seyi
 * arka uca aktarmak, semanin `extra="forbid"` kapisina takilan sessiz
 * 422'ler uretirdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const govde = (await req.json().catch(() => ({}))) as {
    stream_url?: string;
    tur?: string;
  };
  return proxyJson("/cameras/test-baglanti", "POST", {
    stream_url: govde.stream_url ?? "",
    tur: govde.tur ?? "rtsp",
  });
}
