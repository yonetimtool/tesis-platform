import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P155 §7) Yonetici: tesisin davetleri + son gonderim durumu.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/davet", "GET");
}
