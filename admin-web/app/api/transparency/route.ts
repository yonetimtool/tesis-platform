import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Şeffaflık ay listesi (admin salt-okuma). Admin yönetim rolündedir -> tüm aday
// aylar + yayın durumu döner (backend RBAC).
export async function GET(): Promise<NextResponse> {
  return proxyJson("/transparency", "GET");
}
