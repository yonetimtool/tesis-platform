import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  istek: Request,
  { params }: { params: { il: string; ilce: string; mahalle: string;
                          kategori: string } },
): Promise<NextResponse> {
  const p = [params.il, params.ilce, params.mahalle, params.kategori]
    .map(encodeURIComponent)
    .join("/");
  return backendeIlet(istek, `/dukkan/sayfa/${p}`);
}
