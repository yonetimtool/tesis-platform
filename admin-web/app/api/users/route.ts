import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  const role = sp.get("role");
  if (role) qs.set("role", role);
  const isActive = sp.get("is_active");
  if (isActive === "true" || isActive === "false") qs.set("is_active", isActive);
  const q = sp.get("q");
  if (q) qs.set("q", q);
  return proxyJson(`/users?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/users", "POST", body);
}
