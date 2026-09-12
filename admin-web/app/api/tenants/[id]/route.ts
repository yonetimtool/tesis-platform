import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ id: string }> };

// Tesis detayi (tenant + yoneticisi). Admin-only (backend RBAC).
export async function GET(_req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  return proxyJson(`/tenants/${id}`, "GET");
}

// Tesis adini degistir (rename). Admin-only.
export async function PATCH(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`/tenants/${id}`, "PATCH", body);
}

// Tesisi + TUM verisini siler (cascade, geri alinamaz).
//
// (P224) `onay` SORGU PARAMETRESI TASINIR: sunucu tesisin ADINI bekler.
// Tasimazsak panel 409 alir ve kullanici sebebini goremez; daha kotusu,
// onayi yalniz panelde zorlamis olurduk ve ucu dogrudan cagiran her sey
// (betik, curl, ileride baska bir istemci) korumasiz kalirdi.
export async function DELETE(req: NextRequest, ctx: Ctx): Promise<NextResponse> {
  const { id } = await ctx.params;
  const onay = new URL(req.url).searchParams.get("onay") ?? "";
  return proxyJson(
    `/tenants/${id}?onay=${encodeURIComponent(onay)}`,
    "DELETE",
  );
}
