import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P155 §7) Davet jetonunu cozer. PUBLIC: kullanicinin henuz oturumu yok.
export async function POST(req: NextRequest): Promise<NextResponse> {
  return anonimVekil("/davet/coz", await req.json().catch(() => ({})));
}
