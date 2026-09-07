import { NextResponse } from "next/server";

import { vekilGet } from "@/lib/dukkan-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  istek: Request,
  { params }: { params: { il: string } },
): Promise<NextResponse> {
  return vekilGet(
    istek,
    `/dukkan/lokasyon/il/${encodeURIComponent(params.il)}/ilce`,
  );
}
