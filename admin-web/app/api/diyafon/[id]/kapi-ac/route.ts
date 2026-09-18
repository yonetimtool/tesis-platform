import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §2) KAPI ACMA — fiziksel erisim veren eylem; arka uc her
// cagriyi denetim kaydina yazar.
export async function POST(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/diyafon/${params.id}/kapi-ac`, "POST", {});
}
