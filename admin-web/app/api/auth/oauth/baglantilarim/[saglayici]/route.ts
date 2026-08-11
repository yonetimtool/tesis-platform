import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function DELETE(
  _req: Request,
  ctx: { params: Promise<{ saglayici: string }> },
): Promise<NextResponse> {
  const { saglayici } = await ctx.params;
  return proxyJson(
    `/auth/oauth/baglantilarim/${encodeURIComponent(saglayici)}`,
    "DELETE",
  );
}
