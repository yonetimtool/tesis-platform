import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.3) Oturumdaki kullanicinin KENDI profili — her tesis rolu icin. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/profile", "GET");
}
