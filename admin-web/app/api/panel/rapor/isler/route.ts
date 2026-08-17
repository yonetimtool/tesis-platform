import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §5) Rapor ISLERIM.
 *
 * `[kaynak]` beyaz listesine EKLENMEDI, ayri dosya yazildi: `isler` ayni
 * zamanda `rapor/[kod]` dinamik segmentinin bir degeri olabilirdi.
 * Next'te DUZ SEGMENT dinamigi yener; bu dosyanin varligi
 * `/api/panel/rapor/isler` yolunu KESIN olarak buraya baglar ve
 * "isler adinda bir rapor kodu" karmasasini imkansiz kilar.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/raporlar/isler", "GET");
}
