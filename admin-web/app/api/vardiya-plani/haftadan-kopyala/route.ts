import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Haftadan kopyala — atlama SEBEPLERI yanitta doner.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/vardiya-plani/haftadan-kopyala", "POST", body);
}
