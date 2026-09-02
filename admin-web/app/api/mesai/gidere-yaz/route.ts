import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §5) Fazla mesaiyi ONAY BEKLEYEN gider olarak yaz.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/mesai/gidere-yaz", "POST", body);
}
