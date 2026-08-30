import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191 §2) KENDI cihazina test bildirimi. Govde YOK — hedef daima
 * cagiranin kendisidir (arka uc de bunu zorlar).
 */
export async function POST(): Promise<NextResponse> {
  return proxyJson("/push/test", "POST", {});
}
