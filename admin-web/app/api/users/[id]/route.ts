import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/users/${params.id}`, "GET");
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/users/${params.id}`, "PATCH", body);
}

// (P189) DELETE eksikti -> panel sil dugmesi 405 aliyordu (P173 sinifiyla ayni
// BFF eksik-rota). Backend akilli siler (gecmis yoksa sert, varsa anonimlestir)
// ve {deleted} doner; passthrough oldugu gibi gecirir.
export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  return proxyJson(`/users/${params.id}`, "DELETE");
}
