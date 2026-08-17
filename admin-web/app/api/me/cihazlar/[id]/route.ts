import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) Bir cihazi kaldir. Sahiplik kontrolu SUNUCUDA (`user_id` ile
 * kapali sorgu, bulunamayan satir 404) — burada yalnizca iletim var.
 */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/me/cihazlar/${params.id}`, "DELETE");
}
