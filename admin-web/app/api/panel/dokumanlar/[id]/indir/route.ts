import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f-]{36}$/i;

/**
 * (P167 §6.3) DOKUMAN INDIRME BAGLANTISI.
 *
 * Vekil dosyayi KENDISI TASIMAZ, kisa omurlu bir presigned URL doner:
 * 25 MB'lik bir dosyayi Next surecinden gecirmek, sunucuyu obje
 * deposunun onunde gereksiz bir boru hattina cevirirdi.
 *
 * `[kaynak]/[id]` vekiline birakilamadi: o dosya alt yol TANIMAZ ve
 * `/dokumanlar/{id}/indir` ucuncu bir segment tasiyor.
 */
export async function GET(
  _req: Request,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  return proxyJson(`/dokumanlar/${params.id}/indir`, "GET");
}
