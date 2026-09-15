import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P237 §2) GOREV ALT ADIMLARI — liste + ekleme.
 *
 * P189/P226/P229'da olculen sinif burada TEKRARLANMASIN diye ikisi de
 * AYNI dosyada export ediliyor: bir metodu unutmak, arka uc ve sayfa
 * dogruyken istegin 405 almasi demek.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const qs = req.nextUrl.search;
  return proxyJson(`/tasks/${params.id}/adimlar${qs}`, "GET");
}

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tasks/${params.id}/adimlar`, "POST", body);
}
