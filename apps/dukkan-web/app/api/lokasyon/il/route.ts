import { NextResponse } from "next/server";

import { backendenAl } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Il listesi — mahalle secici ve arama kutusu icin. */
export async function GET(): Promise<NextResponse> {
  return backendenAl("/dukkan/lokasyon/il");
}
