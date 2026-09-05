import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** (P213 §6) Gecmis kayit ARAMASI — kayit bulunan araliklar.
 *
 * Yetki BURADA DEGIL sunucuda: uc `admin/yonetici/guvenlik_amiri` ister
 * (routers/cameras.py `_KAYIT_IZLEYICI`). BFF yalniz iletir — istemcide
 * gizlemek yetkilendirme olmaz.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    bas: sp.get("bas") ?? "",
    bit: sp.get("bit") ?? "",
  });
  return proxyJson(`/cameras/${params.id}/kayit/araliklar?${qs}`, "GET");
}
