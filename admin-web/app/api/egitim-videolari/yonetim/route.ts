import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { setSorgusu } from "@/lib/egitim-bff";


export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P250 §4) Panel: setin adimlari + kayitli videolar (platform admini). */
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/egitim-videolari/yonetim${setSorgusu(req)}`, "GET");
}
