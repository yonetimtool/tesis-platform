import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P126.5) Yonetim iletisim karti — SALT OKUMA. */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/yonetici-iletisim", "GET");
}
