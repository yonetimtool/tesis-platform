import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P229 §3) TAMAMLAMAYI GERI AL — gorevi yeniden acar.
 *
 * YETKI KURALI SUNUCUDA: arka uc `_REOPENER` (admin + yonetici) ile
 * korur. BFF yalnizca yolu acar; burada bir rol kontrolu yapmak, iki
 * yerde ayrisabilecek IKINCI bir kural olurdu.
 */
export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string; completionId: string } },
): Promise<NextResponse> {
  return proxyJson(
    `/tasks/${params.id}/completions/${params.completionId}`,
    "DELETE",
  );
}
