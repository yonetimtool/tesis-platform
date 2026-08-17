import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Sahiplik kapisi SUNUCUDA (`user_id` sorgunun icinde, bulunamayan 404);
// burada yalnizca iletim var.
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/hatirlatmalar/${params.id}`, "PATCH", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/hatirlatmalar/${params.id}`, "DELETE");
}
