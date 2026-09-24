import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P247 §1) Bir kisinin dongusunu verilen tarihten itibaren bitir.
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(
    `/vardiya-plani/dongu-atamalari/${params.id}/sonlandir`,
    "POST",
    body,
  );
}
