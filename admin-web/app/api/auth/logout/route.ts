import { NextResponse } from "next/server";

import { backendCikis, logoutResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(): Promise<NextResponse> {
  // (E2E 2026-09) Once SUNUCUDA kapat (refresh ailesi + erisim jetonu),
  // sonra cerezleri sil.
  await backendCikis();
  return logoutResponse();
}
