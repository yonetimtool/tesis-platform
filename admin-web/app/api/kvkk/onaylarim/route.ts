import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P170 §2) KENDI ONAY GECMISIM. Sorgu sunucuda `user_id` ile sinirli;
// yonetici bile buradan baskasinin onayini goremez.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/kvkk/onaylarim", "GET");
}
