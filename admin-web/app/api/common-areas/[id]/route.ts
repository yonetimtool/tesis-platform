import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P181 Bölüm 9) ALAN DÜZENLE / PASİFLEŞTİR (soft-delete `aktif:false`).
// Yalniz yonetim (backend `_MANAGER`); saat tutarliligi + ad benzersizligi
// SUNUCUDA (kapanis > acilis 422, ad cakismasi 409).
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
  const { id } = await params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/common-areas/${encodeURIComponent(id)}`, "PATCH", body);
}
