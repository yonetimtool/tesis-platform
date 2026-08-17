import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f-]{36}$/i;

/**
 * (P167 §5) Hazir raporun INDIRME BAGLANTISI.
 *
 * Vekil dosyayi KENDISI TASIMAZ, kisa omurlu bir presigned URL doner:
 * megabaytlarca XLSX'i Next surecinden gecirmek, sunucuyu obje deposunun
 * onunde gereksiz bir boru hattina cevirirdi.
 */
export async function GET(
  _req: Request,
  { params }: { params: { is_id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.is_id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  return proxyJson(`/raporlar/isler/${params.is_id}/indir`, "GET");
}
