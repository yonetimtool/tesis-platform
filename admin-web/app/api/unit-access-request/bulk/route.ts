import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P251 §8) Tum sakinli dairelerden izin iste (her daire kendi onayina bagli). */
export async function POST(): Promise<NextResponse> {
  return proxyJson("/unit-access-request/bulk", "POST", {});
}
