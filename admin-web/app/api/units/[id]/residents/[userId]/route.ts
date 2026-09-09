import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P220 §5) BU DAIREDEKI bagi gunceller — rol / oturuyor.
 *
 * `PATCH /residents/{userId}` DEGIL: o uc kullanicinin AKTIF TUM daire
 * baglarina uyguluyor ve iki dairesi olan bir sakinde (birinde malik,
 * otekinde kiraci) daire penceresinden yapilan degisiklik IKISINI DE
 * degistirirdi.
 *
 * BFF vekili olmadan bu uc web'den cagrilinca 405 alirdi ve backend
 * testleri bunu GORMEZDI (P173/P189'da iki kez olculdu). */
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string; userId: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(
    `/units/${params.id}/residents/${params.userId}`,
    "PATCH",
    body,
  );
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string; userId: string } },
): Promise<NextResponse> {
  return proxyJson(`/units/${params.id}/residents/${params.userId}`, "DELETE");
}
