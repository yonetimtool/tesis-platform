import { NextRequest, NextResponse } from "next/server";
import { istekMetni } from "@/lib/i18n/istek-metni";

import { backendLogin, loginResponse } from "@/lib/backend";
import { tokenRolu } from "@/lib/rol-token";
import {
  konakYuzeyi,
  rolYuzeyeGirebilir,
  tesisYuzeyiBekleyenRol,
} from "@/lib/yuzey";

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
      { error: { code: "validation_error", message: istekMetni(req, "girisAlanZorunlu") } },
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
      data ?? { error: { code: "error", message: istekMetni(req, "girisBasarisiz") } },
      { status },
    );
  }

  const tokens = data as { access_token: string; refresh_token: string };

  // (P126.1) KAPI ARTIK YUZEYE GORE.
  //
  // `panel.*` platform sahibinindir; `app.*` tesis rollerinindir. Ayni Next
  // uygulamasi iki alan adindan sunuldugu icin karar KONAKTAN verilir
  // (bkz. infra/Caddyfile ve lib/yuzey.ts).
  //
  // BU BIR UX KAPISIDIR, GUVENLIK SINIRI DEGIL: gercek yetki her istekte
  // backend RBAC'ta zorlanir (contracts/auth.md §4). Ama yanlis yuzeye
  // giren kullaniciya isini yapamayacagi bir kabuk gostermek "sistem bozuk"
  // izlenimi uretir — kapi bunu onler ve NEDENINI soyler.
  const rol = tokenRolu(tokens.access_token);
  const yuzey = konakYuzeyi(req.headers.get("host"));
  if (!rolYuzeyeGirebilir(rol, yuzey)) {
    // Sayfalari HENUZ olmayan tesis rolleri icin ayri bir cumle: "panel
    // yalnizca platform icindir" demek onlari yanlis yere yollardi.
    const anahtar =
      yuzey === "tesis" && tesisYuzeyiBekleyenRol(rol)
        ? "girisRolYakinda"
        : "girisPanelPlatformIcin";
    return NextResponse.json(
      { error: { code: "forbidden", message: istekMetni(req, anahtar) } },
      { status: 403 },
    );
  }

  return loginResponse(tokens.access_token, tokens.refresh_token);
}
