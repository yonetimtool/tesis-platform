import { NextResponse } from "next/server";

import { logoutResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(): Promise<NextResponse> {
  return logoutResponse();
}
