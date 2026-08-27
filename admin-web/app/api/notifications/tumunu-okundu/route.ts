import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P181 Bölüm 6.5) Kapsamdaki tum okunmamislari okundu isaretle.
export async function POST(): Promise<NextResponse> {
  return proxyJson("/notifications/tumunu-okundu", "POST", {});
}
