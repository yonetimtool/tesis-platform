import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { setSorgusu } from "@/lib/egitim-bff";


export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P250 §4) Panel: adimin videosunu yaz (YouTube baglantisi -> kimlik). */
export async function PUT(
  req: NextRequest,
  { params }: { params: { adim: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(
    `/egitim-videolari/yonetim/${encodeURIComponent(params.adim)}${setSorgusu(req)}`,
    "PUT",
    body,
  );
}

/** (P250 §4) Panel: adimin videosunu kaldir. */
export async function DELETE(
  req: NextRequest,
  { params }: { params: { adim: string } },
): Promise<NextResponse> {
  return proxyJson(
    `/egitim-videolari/yonetim/${encodeURIComponent(params.adim)}${setSorgusu(req)}`,
    "DELETE",
  );
}
