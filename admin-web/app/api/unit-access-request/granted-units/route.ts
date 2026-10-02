import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P251 §8) Su an goruntulenebilecek daireler (onayli + kullanilmamis). */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/unit-access-request/granted-units", "GET");
}
