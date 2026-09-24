import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { REFRESH_COOKIE } from "@/lib/cookies";
import { istekMetni } from "@/lib/i18n/istek-metni";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P247 §2) AKTIF ROL + GECILEBILECEK ROLLER — `GET /me` vekili.
 *
 * `/api/me` PROFIL ucuna (`/me/profile`) gider ve orada `roller` yok;
 * profil menusu "iki secenek cizilsin mi" sorusunun cevabini buradan
 * alir (tek eleman = menu YOK).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me", "GET");
}

/**
 * (P247 §2) YONETICI <-> SAKIN GECISI — yeni jeton cifti CEREZE yazilir.
 *
 * REFRESH JETONU GOVDEYE KONUR: sunucu verilen refresh ailesini kapatir
 * ki iki mod ayni anda acik kalmasin (eski erisim jetonu da kara listeye
 * girer). Jeton httpOnly cerezde durdugu icin bunu yalniz BFF yapabilir.
 *
 * YENI JETON YUZEY KAPISINDAN GECER (`oturumAc`) — tesis degistirmenin
 * gerekcesiyle ayni: rol degisti; kapiyi yalniz giriste uygulamak,
 * gecisle girilemeyecek bir yuzeye DUSMEK olurdu. Sakin modu jetonu
 * (`resident` + `asil_rol:yonetici`) web rolu `SAKIN_MODU` olarak
 * okunur ve `app.*`a girer; saf sakin bu uca hic ulasamaz (sunucu 403).
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const govde = (await req.json().catch(() => ({}))) as { rol?: unknown };
  const rol = govde.rol === "yonetici" || govde.rol === "resident" ? govde.rol : null;
  if (!rol) {
    return NextResponse.json(
      { error: { code: "validation_error", message: istekMetni(req, "ortakHataOlustu") } },
      { status: 422 },
    );
  }
  const refresh = req.cookies.get(REFRESH_COOKIE)?.value ?? null;
  const res = await proxyJson("/me/rol-gecis", "POST", {
    rol,
    refresh_token: refresh,
  });
  if (!res.ok) return res;

  const veri = (await res.json().catch(() => null)) as {
    access_token?: string;
    refresh_token?: string;
  } | null;
  if (!veri?.access_token || !veri.refresh_token) {
    return NextResponse.json(
      { error: { code: "error", message: istekMetni(req, "ortakHataOlustu") } },
      { status: 502 },
    );
  }
  return oturumAc(req, veri.access_token, veri.refresh_token);
}
