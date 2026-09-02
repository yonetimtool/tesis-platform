import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P203 §2) Oturumdaki kisinin tesis uyelikleri — uygulama ici secici.
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/tesislerim", "GET");
}
