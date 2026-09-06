import { NextResponse } from "next/server";

import { backendenAl } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  _istek: Request,
  { params }: { params: { il: string } },
): Promise<NextResponse> {
  return backendenAl(
    `/dukkan/lokasyon/il/${encodeURIComponent(params.il)}/ilce`,
  );
}
