import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/patrol-plans/${params.id}/checkpoints`, "GET");
}

// Tam degisim (replace): { items: [{ checkpoint_id, sira? }] }
export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/patrol-plans/${params.id}/checkpoints`, "PUT", body);
}
