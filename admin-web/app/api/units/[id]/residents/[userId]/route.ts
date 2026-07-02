import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string; userId: string } },
): Promise<NextResponse> {
  return proxyJson(`/units/${params.id}/residents/${params.userId}`, "DELETE");
}
