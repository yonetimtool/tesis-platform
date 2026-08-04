import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.6) Gorev tamamlama.
 *
 * `Idempotency-Key` ILETILIR: sunucu onu ZORUNLU tutuyor (400
 * `idempotency_key_zorunlu`). Cift tiklama ya da ag tekrari, ayni gorevi
 * iki kez tamamlanmis gostermemeli.
 */
export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } },
): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  const key = req.headers.get("Idempotency-Key");
  return proxyJson(
    `/tasks/${params.id}/completions`,
    "POST",
    body,
    key ? { "Idempotency-Key": key } : undefined,
  );
}
