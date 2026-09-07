import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** BFF vekili — tarayici tarafi arama kutusu icin. */
export async function GET(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/isletme-ara");
}
