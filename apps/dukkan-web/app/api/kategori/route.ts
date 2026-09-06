import { NextResponse } from "next/server";

import { backendenAl } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(): Promise<NextResponse> {
  return backendenAl("/dukkan/kategori");
}
