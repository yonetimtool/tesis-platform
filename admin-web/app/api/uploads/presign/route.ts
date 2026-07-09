import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Foto yukleme bileti (duyuru gorseli vb.). Dosyanin kendisi BFF'den
// GECMEZ: tarayici presigned URL'e dogrudan PUT eder (MinIO CORS acik).
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/uploads/presign", "POST", body);
}
