import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P253 §D) "Asilsiz" isareti (gerekce zorunlu) ve geri alinmasi —
// admin+yonetici (backend RBAC zorlar). Sikayet edenin kimligi DONMEZ.
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/unit-complaints/${params.id}/asilsiz`, "POST", body);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/unit-complaints/${params.id}/asilsiz`, "DELETE");
}
