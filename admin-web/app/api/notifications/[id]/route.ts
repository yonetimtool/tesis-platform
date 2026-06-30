import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = (await req.json().catch(() => ({}))) as { okundu?: boolean };
  return proxyJson(`/notifications/${params.id}`, "PATCH", {
    okundu: body.okundu ?? true,
  });
}
