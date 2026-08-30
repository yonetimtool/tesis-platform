import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P191 §4) Eslestirme kosumu. Govde YOK — hedef kumeyi sunucu secer. */
export async function POST(): Promise<NextResponse> {
  return proxyJson("/banka/eslestir", "POST", {});
}
