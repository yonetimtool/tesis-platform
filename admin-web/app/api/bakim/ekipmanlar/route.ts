import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §1) Bakim ekipmanlari — liste + tanimlama.
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/bakim/ekipmanlar${req.nextUrl.search}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/bakim/ekipmanlar", "POST", body);
}
