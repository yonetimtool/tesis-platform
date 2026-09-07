import { NextResponse } from "next/server";

import { backendeIlet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(istek: Request): Promise<NextResponse> {
  return backendeIlet(istek, "/dukkan/sitemap/sayfalar");
}
