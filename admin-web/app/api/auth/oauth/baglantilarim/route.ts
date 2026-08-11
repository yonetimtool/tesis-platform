import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P154 / Asama 4) KENDI giris yontemlerim. Oturum ZORUNLU — bu yuzden
// `proxyJson` (cerezli vekil), `anonimVekil` degil.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/auth/oauth/baglantilarim", "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  return proxyJson(
    "/auth/oauth/baglantilarim",
    "POST",
    await req.json().catch(() => ({})),
  );
}
