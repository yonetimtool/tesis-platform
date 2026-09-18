import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §3) Olay jetonu — YANITTA BIR KEZ doner, sonra okunamaz.
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/akilli-ev/koprular/${params.id}/olay-jetonu`, "POST", {});
}
