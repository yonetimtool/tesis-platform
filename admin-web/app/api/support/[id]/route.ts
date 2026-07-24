import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Admin yaniti: durum (acik|cozuldu) + admin_cevap (backend RBAC + 404).
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/support/${id}`, "PATCH", body);
}
