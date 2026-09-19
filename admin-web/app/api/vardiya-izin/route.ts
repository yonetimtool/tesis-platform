import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P241 §2) Izinler — liste + ekleme/talep.
export async function GET(req: NextRequest): Promise<NextResponse> {
  return proxyJson(`/vardiya-izin${req.nextUrl.search}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/vardiya-izin", "POST", body);
}
