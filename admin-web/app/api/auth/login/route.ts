import { NextRequest, NextResponse } from "next/server";

import { backendLogin, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = (await req.json().catch(() => ({}))) as {
    tenant_slug?: string;
    email?: string;
    password?: string;
  };
  if (!body.tenant_slug || !body.email || !body.password) {
    return NextResponse.json(
      { error: { code: "validation_error", message: "tenant_slug, email ve parola zorunlu." } },
      { status: 400 },
    );
  }

  const { ok, status, data } = await backendLogin({
    tenant_slug: body.tenant_slug,
    email: body.email,
    password: body.password,
  });

  if (!ok) {
    return NextResponse.json(
      data ?? { error: { code: "error", message: "Giris basarisiz." } },
      { status },
    );
  }

  const tokens = data as { access_token: string; refresh_token: string };
  return loginResponse(tokens.access_token, tokens.refresh_token);
}
