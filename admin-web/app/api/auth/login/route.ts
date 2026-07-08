import { NextRequest, NextResponse } from "next/server";

import { backendLogin, loginResponse } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Access token claim'inden rolu okur (imza DOGRULANMAZ — token'i backend'in
// kendisi verdi; bu kontrol yalnizca panel UX kapisidir. Gercek yetki her
// istekte backend RBAC'ta zorlanir — bkz. contracts/auth.md §4).
function tokenRole(access: string): string | null {
  try {
    const payload = access.split(".")[1] ?? "";
    const json = Buffer.from(payload, "base64url").toString("utf8");
    return (JSON.parse(json) as { role?: string }).role ?? null;
  } catch {
    return null;
  }
}

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

  // Panel YALNIZ platform admini icindir (contracts/auth.md §4) — diger roller
  // (yonetici dahil) mobil uygulamayi kullanir; cookie SET EDILMEZ.
  if (tokenRole(tokens.access_token) !== "admin") {
    return NextResponse.json(
      {
        error: {
          code: "forbidden",
          message:
            "Yonetim paneli yalnizca platform admini icindir. Yonetici ve saha hesaplari mobil uygulamayi kullanir.",
        },
      },
      { status: 403 },
    );
  }

  return loginResponse(tokens.access_token, tokens.refresh_token);
}
