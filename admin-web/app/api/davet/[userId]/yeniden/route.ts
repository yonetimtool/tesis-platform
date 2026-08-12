import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P155 §7) Yonetici: bir kullanicinin davetini tazeler ve yeniden gonderir.
export async function POST(
  _req: NextRequest,
  { params }: { params: { userId: string } },
): Promise<NextResponse> {
  return proxyJson(`/davet/${params.userId}/yeniden`, "POST");
}
